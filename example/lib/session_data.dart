import 'package:flutter_next_auth_core/next_auth.dart';

class SessionUser {
  final String id;
  final String nickname;
  final String email;
  final String? image;

  SessionUser({
    required this.id,
    required this.nickname,
    required this.email,
    required this.image,
  });
}

class SessionData {
  final SessionUser user;
  final List<String> roles;
  final DateTime? emailVerified;
  final String loginType;
  final String visitMode;

  SessionData({
    required this.user,
    required this.roles,
    this.emailVerified,
    required this.loginType,
    required this.visitMode,
  });
}

// Or for simplicity, you can just use Map<String, dynamc> as the SessionData type, so the conversion will be just an 'as Map<String, dynamic>'
class SessionDataSerializer implements SessionSerializer<SessionData> {
  @override
  SessionData? fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) return null;

    final userRaw = json['user'];
    final userMap = userRaw is Map<String, dynamic> ? userRaw : json;

    final rolesRaw = json['roles'];
    final roles = rolesRaw is List
        ? rolesRaw.whereType<String>().toList()
        : <String>[];

    final emailVerifiedRaw = json['emailVerified'];
    final emailVerified = emailVerifiedRaw is String
        ? DateTime.tryParse(emailVerifiedRaw)
        : null;

    return SessionData(
      user: SessionUser(
        id: (userMap['id'] ?? '').toString(),
        nickname: (userMap['nickname'] ?? '').toString(),
        email: (userMap['email'] ?? '').toString(),
        image: userMap['image']?.toString(),
      ),
      roles: roles,
      emailVerified: emailVerified,
      loginType: (json['loginType'] ?? '').toString(),
      visitMode: (json['visitMode'] ?? '').toString(),
    );
  }

  @override
  Map<String, dynamic> toJson(SessionData data) {
    return {
      'user': {
        'id': data.user.id,
        'nickname': data.user.nickname,
        'email': data.user.email,
        'image': data.user.image,
      },
      'roles': data.roles,
      'loginType': data.loginType,
      'visitMode': data.visitMode,
      'emailVerified': data.emailVerified?.toIso8601String(),
    };
  }
}
