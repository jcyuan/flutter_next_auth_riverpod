import 'server-only';

import { prisma } from '@/data/prisma';
import { createLoginLog } from '@/data/repository/login-log';
import { appOAuthValidationRules } from '@/data/validation/api-rules';
import { safeInputJson } from '@/libs/api/input';
import { apiError, apiSuccess } from '@/libs/api/result';
import { authOptions } from '@/libs/auth/options';
import logger from '@/libs/logger';
import { exchangeOAuthCode } from '@/libs/oauth/callback';
import { createOAuthClient } from '@/libs/oauth/client';
import { OAuthProvider, oauthProviders } from '@/libs/oauth/providers';
import { verifyIdToken } from '@/libs/oauth/verify-idtoken';
import { getClientIp } from '@/libs/request-ip';
import { CustomErrorCode } from '@/types/api';
import { PrismaAdapter } from '@next-auth/prisma-adapter';
import { LoginClientType } from '@prisma/client';
import type { Awaitable, Profile, User } from 'next-auth';
import { encode, JWT } from 'next-auth/jwt';
import type { OAuthConfig } from 'next-auth/providers/oauth';
import { NextRequest } from 'next/server';
import { TokenSet } from 'openid-client';
import { verifyTurnstileToken } from '@/utils/turnstile';

const prismaAdapter = PrismaAdapter(prisma);

export async function POST(req: NextRequest) {
    const input = await safeInputJson(req);
    if (!input) {
        return apiError(CustomErrorCode.PARAM_ERROR, 'api-errors.invalid-request');
    }

    const parsed = await appOAuthValidationRules.safeParseAsync(input);
    if (!parsed.success) {
        return apiError(CustomErrorCode.PARAM_ERROR, parsed.error.issues[0].message);
    }

    const { idToken, code, provider, turnstile } = parsed.data;
    
    if (!turnstile || turnstile === 'undefined')
        return apiError(CustomErrorCode.OPERATION_NOT_ALLOWED, "api-errors.missing-recaptcha");

    const ip = getClientIp(req);
    const turnstileResponse = await verifyTurnstileToken(turnstile, ip);
    if (!turnstileResponse.success) {
        logger.error(`Verify turnstile token error [${ turnstileResponse['error-codes'] }]: ${ turnstileResponse.messages }`);
        return apiError(CustomErrorCode.OPERATION_NOT_ALLOWED, "api-errors.invalid-recaptcha");
    }

    const ua = req.headers.get('user-agent') ?? '';

    const oauthConfig = oauthProviders[provider as OAuthProvider];
    if (!oauthConfig || !oauthConfig.clientId || !oauthConfig.clientSecret) {
        return apiError(CustomErrorCode.PARAM_ERROR, 'oauth.invalid-provider');
    }
    
    try {
        const nextAuthProvider = authOptions.providers.find(p => p.id === provider) as OAuthConfig<unknown> | undefined;
        if (!nextAuthProvider) {
            throw new Error('NextAuth provider is not defined');
        }
        
        const profileUserConverter: ((profile: unknown, tokens: TokenSet) => Awaitable<User>) | undefined = nextAuthProvider?.options?.profile;
        if (!profileUserConverter || typeof profileUserConverter !== 'function') {
            throw new Error('Profile user converter is not defined');
        }

        if (!authOptions.callbacks?.jwt) {
            throw new Error('JWT callback is not defined');
        }

        if (!authOptions.callbacks?.signIn) {
            throw new Error('Sign in callback is not defined');
        }

        let profileUser: User;

        const client = await createOAuthClient(oauthConfig);
        let tokens: TokenSet;
        let rawProfile: unknown;
        
        if (code) {
            // Flow 1: Has code - Full OAuth flow
            const result = await exchangeOAuthCode(code, oauthConfig);
            rawProfile = result.profile;
            tokens = result.tokens;
            
            profileUser = await profileUserConverter(rawProfile, result.tokens);

            if (!profileUser || !profileUser.email || !profileUser.id) {
                throw new Error('Invalid profile user');
            }

            // Verify that the idToken from app matches the id_token from code exchange
            if (tokens.id_token !== idToken) {
                // Compare by sub claim instead of exact match
                const appIdTokenClaims = await verifyIdToken(client, idToken, oauthConfig);
                if (appIdTokenClaims.sub !== profileUser.id) {
                    createLoginLog({
                        ip,
                        account: profileUser.email,
                        userAgent: ua,
                        success: false,
                        error: 'oauth.idtoken-mismatch',
                        loginTime: new Date(),
                        loginType: 'oauth',
                        loginProvider: provider,
                        loginClient: LoginClientType.APP,
                    });
                    return apiError(CustomErrorCode.PARAM_ERROR, 'oauth.idtoken-mismatch');
                }
            }
        } else {
            // Flow 2: No code - Only idToken verification
            const idTokenClaims = await verifyIdToken(client, idToken, oauthConfig);
            rawProfile = idTokenClaims;
            tokens = new TokenSet({ id_token: idToken });

            profileUser = await profileUserConverter(rawProfile, tokens);

            if (!profileUser || !profileUser.email || !profileUser.id) {
                throw new Error('Invalid profile user');
            }
        }
        
        // Prepare account data (following NextAuth's handle-login.ts logic)
        const scopeStr = tokens.scope || (typeof oauthConfig.scope === 'string' ? oauthConfig.scope : oauthConfig.scope.join(' '));
        const baseAccountData = {
            provider,
            type: 'oauth' as const,
            providerAccountId: profileUser.id,
            refresh_token: tokens.refresh_token ?? undefined,
            access_token: tokens.access_token ?? undefined,
            expires_at: tokens.expires_at ?? undefined,
            token_type: 'Bearer' as const,
            scope: scopeStr,
            id_token: tokens.id_token,
        };
        
        // Process account using provider.account method (if available, following NextAuth's logic)
        let accountData = baseAccountData;
        if ('account' in nextAuthProvider && typeof nextAuthProvider.account === 'function') {
            const { type, provider, providerAccountId, ...tokenSet } = baseAccountData;
            const processedAccount = nextAuthProvider.account(tokenSet);
            if (processedAccount) {
                accountData = Object.assign(processedAccount, {
                    providerAccountId,
                    provider,
                    type,
                });
            }
        }

        // Use NextAuth adapter to find or create user and account (following handle-login.ts)
        let user = await prismaAdapter.getUserByAccount?.({
            providerAccountId: accountData.providerAccountId,
            provider: accountData.provider,
        }) || null;

        let isNewUser = false;

        if (user) {
            // Account exists, user found - update tokens if needed
            await prisma.account.update({
                where: {
                    provider_providerAccountId: {
                        provider: accountData.provider,
                        providerAccountId: accountData.providerAccountId,
                    },
                },
                data: {
                    refresh_token: accountData.refresh_token,
                    access_token: accountData.access_token,
                    expires_at: accountData.expires_at,
                    id_token: accountData.id_token,
                    updatedAt: new Date(),
                },
            });
        } else {
            const userByEmail = profileUser.email
                ? await prismaAdapter.getUserByEmail?.(profileUser.email) || null
                : null;

            if (userByEmail) {
                if (nextAuthProvider?.options?.allowDangerousEmailAccountLinking) {
                    user = userByEmail;
                    isNewUser = false;
                } else {
                    // Email account linking not allowed - throw error (same as NextAuth)
                    return apiError(
                        CustomErrorCode.OPERATION_NOT_ALLOWED,
                        'oauth.account-not-linked'
                    );
                }
            } else {
                const { id: _, emailVerified: __, ...newUserData } = profileUser;
                user = await prismaAdapter.createUser?.({
                    ...newUserData,
                    emailVerified: profileUser.emailVerified,
                });
                
                if (!user) {
                    throw new Error('Failed to create user');
                }

                isNewUser = true;
                await authOptions.events?.createUser?.({ user });
            }

            // Link account to user
            await prismaAdapter.linkAccount?.({ ...accountData, userId: user.id });
            await authOptions.events?.linkAccount?.({
                user,
                account: accountData,
                profile: profileUser,
            });
        }

        if (!user) {
            throw new Error('User not found or created');
        }

        // Get user with roles for JWT callback
        const userWithRoles = await prisma.user.findUnique({
            where: { id: user.id },
            include: {
                userRoleLinks: {
                    include: {
                        role: {
                            select: { name: true },
                        },
                    },
                },
            },
        });
        const roles = (userWithRoles?.userRoleLinks?.map((link) => link.role.name) ?? []) as string[];
        
        try {
            const headersObject = Object.fromEntries(req.headers.entries());
            // force login client type to app
            headersObject['login-client'] = LoginClientType.APP;
            
            const signInResult = await authOptions.callbacks.signIn({
                user: { ...user, roles } as User,
                account: accountData,
                profile: rawProfile as Profile,
                email: undefined,
                credentials: undefined,
                headers: headersObject
            });
            
            if (!signInResult) {
                return apiError(CustomErrorCode.OPERATION_NOT_ALLOWED, 'login.error-signin-failed');
            }
        } catch (error) {
            // signIn callback already logged the failure, just return the error message (the message is the reason reported by it)
            return apiError(CustomErrorCode.OPERATION_NOT_ALLOWED, error instanceof Error ? error.message : 'login.error-signin-failed');
        }
        
        // Note: visitMode, loginType, roles will be added by jwt callback
        const defaultToken = {
            name: user.name,
            email: user.email,
            picture: user.image,
            sub: user.id,
        } as JWT;

        const jwtToken = await authOptions.callbacks.jwt({
            token: defaultToken,
            user: { ...user, roles } as User,
            account: accountData,
            profile: rawProfile as Profile,
            isNewUser,
            trigger: isNewUser ? 'signUp' : 'signIn',
        });
        
        if (!jwtToken) {
            return apiError(CustomErrorCode.OPERATION_NOT_ALLOWED, 'oauth.error-token-null');
        }

        const secret = process.env.NEXTAUTH_SECRET;
        if (!secret) {
            throw new Error('NEXTAUTH_SECRET is not set');
        }

        const secureCookie = process.env.NEXTAUTH_URL?.startsWith("https://") ?? !!process.env.VERCEL;
        const maxAge = authOptions.session?.maxAge || 30 * 24 * 60 * 60; // 30 days default
        // according to the nextauth docs, use empty salt for session token
        const salt = "";
        const encodedToken = await encode({
            token: jwtToken,
            secret,
            maxAge,
            // salt,
            salt,
        });

        // TODO: Add refresh token to the response (but NextAuth does not support it yet)
        return apiSuccess({
            accessToken: encodedToken,
            refreshToken: null,
            refreshTokenExpiresAt: null
        }, null, 'oauth.success');
        
    } catch (error) {
        logger.error('OAuth authentication error:', error);
        return apiError(CustomErrorCode.SERVER_ERROR, 'oauth.error-authentication-failed');
    }
}
