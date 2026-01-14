import 'package:flutter/material.dart';
import 'package:flutter_next_auth_core/config/next_auth_config.dart';
import 'package:flutter_next_auth_core/core/next_auth_client.dart';
import 'package:flutter_next_auth_core/events/next_auth_events.dart';
import 'package:flutter_next_auth_core/models/sign_in_options.dart';
import 'package:flutter_next_auth_riverpod/next_auth_riverpod.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:next_auth_client_example/providers/google_oauth_provider.dart';
import 'package:next_auth_client_example/session_data.dart';
import 'package:next_auth_client_example/simple_dio_httpclient.dart';

final getIt = GetIt.instance;

// NextAuthClient with next_auth_riverpod integration example
void main() {
  // create configuration with cookie name comments
  final config = NextAuthConfig(
    domain: 'https://example.com',
    authBasePath: '/api/auth',
    httpClient: SimpleDioHttpClient(),
    // cookie name configuration notes:
    // - serverSessionCookieName: server-side session cookie name (optional)
    //   default value changes dynamically based on protocol:
    //   - HTTPS: '__Secure-next-auth.session-token'
    //   - HTTP: 'next-auth.session-token'
    //   must be the same as the one in the server
    //   recommended to specify a fixed value matching your backend configuration
    serverSessionCookieName: 'next-auth.session-token',
    // - serverCSRFTokenCookieName: server CSRF cookie name (optional)
    //   default value changes dynamically based on protocol:
    //   - HTTPS: '__Host-next-auth.csrf-token'
    //   - HTTP: 'next-auth.csrf-token'
    //   must be the same as the one in the server
    //   recommended to specify a fixed value matching your backend configuration
    serverCSRFTokenCookieName: 'next-auth.csrf-token',
    // - sessionSerializer: session serializer
    //   used to serialize and deserialize session data to and from JSON to pass to the server
    //   you can implement your own session serializer by implementing the SessionSerializer interface
    //   example: DefaultSessionSerializer<MySessionModel>()
    sessionSerializer: SessionDataSerializer(),
  );

  final nextAuthClient = NextAuthClient<SessionData>(config);

  // register Google OAuth provider
  nextAuthClient.registerOAuthProvider("google", GoogleOAuthProvider());
  // register your own OAuth provider implementations
  // nextAuthClient.registerOAuthProvider("apple", AppleOAuthProvider());

  // register NextAuthClient to getIt
  getIt.registerSingleton<NextAuthClient<SessionData>>(nextAuthClient);

  // ============================================================================
  // next_auth_riverpod Integration
  // ============================================================================
  // Use NextAuthRiverpodScope to wrap your app for automatic session management
  runApp(
    NextAuthRiverpodScope<SessionData>(
      client: getIt<NextAuthClient<SessionData>>(),
      // refetchInterval: 30000, // optional: refetch session every 30 seconds
      refetchOnWindowFocus:
          true, // optional: refetch when app comes to foreground
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  bool _isInProgress = false;

  @override
  Widget build(BuildContext context) {
    // ============================================================================
    // Using next_auth_riverpod Providers
    // ============================================================================
    // next_auth_riverpod provides the following providers:
    // - authProvider: NextAuthState<T> - current authentication state
    // - statusProvider: SessionStatus - current session status (initial, loading, authenticated, unauthenticated)
    // - sessionProvider: T? - current session data (null if not authenticated)
    // - authEventStreamProvider: Stream<NextAuthEvent> - stream of authentication events

    final sessionStatus = ref.watch(statusProvider);
    final session = ref.watch(sessionProvider) as SessionData?;
    ref.listen(authEventStreamProvider, (previous, next) {
      next.whenData((event) {
        if (event == null) return;
        if (event is SignedInEvent) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Signed in, jwt token: ${event.accessToken.toJson()}, you may save this for your backend API calls',
              ),
            ),
          );
        } else if (event is SignedOutEvent) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Signed out, you may now clear the jwt token you saved before',
              ),
            ),
          );
        }
      });
    });

    return MaterialApp(
      title: 'NextAuth Riverpod Example',
      home: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('NextAuth Riverpod Example')),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Session Status: ${sessionStatus.name}'),
                    const SizedBox(width: 4),
                    Visibility(
                      visible: _isInProgress,
                      child: const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (session != null)
                  Text('Session: ${session.toString()}')
                else
                  const Text('No session'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: !_isInProgress
                      ? () async {
                          // Example: Sign in with credentials using getIt
                          setState(() {
                            _isInProgress = true;
                          });
                          try {
                            final nextAuthClient =
                                getIt<NextAuthClient<SessionData>>();
                            final response = await nextAuthClient.signIn(
                              'credentials',
                              credentialsOptions: CredentialsSignInOptions(
                                email: 'example@example.com',
                                password: 'password',
                                // Optional but it's recommended to use turnstile token for security
                                // turnstileToken: yourTurnsTileToken
                              ),
                            );
                            if (response.ok) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Sign in successful'),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Sign in failed: ${response.error}',
                                  ),
                                ),
                              );
                            }
                          } finally {
                            setState(() {
                              _isInProgress = false;
                            });
                          }
                        }
                      : null,
                  child: const Text('Sign In with Password'),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: !_isInProgress
                      ? () async {
                          // Example: Sign in with Google OAuth
                          setState(() {
                            _isInProgress = true;
                          });
                          try {
                            final nextAuthClient =
                                getIt<NextAuthClient<SessionData>>();
                            final response = await nextAuthClient.signIn(
                              'google',
                              oauthOptions: OAuthSignInOptions(
                                provider: 'google',
                                // Optional but it's recommended to use turnstile token for security
                                // turnstileToken: yourTurnsTileToken
                              ),
                            );
                            if (response.ok) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Google sign in successful'),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Google sign in failed: ${response.error}',
                                  ),
                                ),
                              );
                            }
                          } finally {
                            if (mounted) {
                              setState(() {
                                _isInProgress = false;
                              });
                            }
                          }
                        }
                      : null,
                  child: const Text('Sign In with Google'),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () async {
                    // Example: Sign out using getIt
                    final nextAuthClient = getIt<NextAuthClient<SessionData>>();
                    await nextAuthClient.signOut();
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('Signed out')));
                  },
                  child: const Text('Sign Out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
