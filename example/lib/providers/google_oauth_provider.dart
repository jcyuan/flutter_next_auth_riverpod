import 'dart:async';
import 'dart:convert';

import 'package:flutter_next_auth_core/oauth/oauth_provider.dart';
import 'package:google_sign_in/google_sign_in.dart';

// example Google OAuth provider implementation
// replace 'YOUR_GOOGLE_CLIENT_ID' and 'YOUR_GOOGLE_SERVER_CLIENT_ID' with your actual Google OAuth credentials
class GoogleOAuthProvider implements OAuthProvider {
  @override
  final String providerName = "google";

  @override
  List<String> get scopes => [
    'openid',
    'https://www.googleapis.com/auth/userinfo.profile',
    'https://www.googleapis.com/auth/userinfo.email',
  ];

  bool _isInitialized = false;
  GoogleSignInAccount? _currentUser;

  @override
  bool get isInitialized => _isInitialized;

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;

    final signIn = GoogleSignIn.instance;

    await signIn.initialize(
      clientId:
          'YOUR_GOOGLE_CLIENT_ID', // replace with your Google OAuth client ID
      serverClientId:
          'YOUR_GOOGLE_SERVER_CLIENT_ID', // replace with your Google OAuth server client ID
    );

    _isInitialized = true;
  }

  @override
  Future<OAuthAuthorizationData> getAuthorizationData() async {
    if (!_isInitialized) {
      throw Exception('GoogleOAuthProvider not initialized');
    }

    final signIn = GoogleSignIn.instance;
    _currentUser ??= await signIn.attemptLightweightAuthentication();

    String? idToken = _currentUser?.authentication.idToken;
    String? authorizationCode;

    if (_currentUser == null || _isJwtExpiredOrNearExpiry(idToken)) {
      _currentUser = await signIn.authenticate();
      authorizationCode =
          (await _currentUser!.authorizationClient.authorizeServer(
            scopes,
          ))?.serverAuthCode;
      idToken = _currentUser!.authentication.idToken;
    }

    assert(
      _currentUser != null,
      'Google sign-in failed: authenticate method returned null',
    );
    assert(
      idToken != null && idToken.isNotEmpty,
      'Google sign-in failed: idToken is null or empty',
    );

    final data = OAuthAuthorizationData(
      authorizationCode: authorizationCode,
      idToken: idToken!,
    );

    return data;
  }

  Map<String, dynamic>? _decodeJwtPayload(String jwt) {
    final parts = jwt.split('.');
    if (parts.length != 3) return null;

    final payload = parts[1];
    final normalized = base64Url.normalize(payload);
    final payloadBytes = base64Url.decode(normalized);
    final payloadString = utf8.decode(payloadBytes);

    final obj = jsonDecode(payloadString);
    return obj is Map<String, dynamic> ? obj : null;
  }

  int? _jwtExpiry(String jwt) {
    final payload = _decodeJwtPayload(jwt);
    if (payload == null) return null;

    final exp = payload['exp'];
    if (exp is! int) return null;

    // seconds since epoch
    return exp;
  }

  bool _isJwtExpiredOrNearExpiry(
    String? jwt, {
    Duration leeway = const Duration(seconds: 30), // clock skew + network
  }) {
    if (jwt == null || jwt.isEmpty) return true;
    final exp = _jwtExpiry(jwt);
    if (exp == null) return true;
    final now = DateTime.now().toUtc().millisecondsSinceEpoch / 1000;
    return now > (exp - leeway.inSeconds);
  }

  @override
  Future<void> signOut() async {
    if (!_isInitialized) return;
    _currentUser = null;
    await GoogleSignIn.instance.disconnect();
    _isInitialized = false;
  }
}
