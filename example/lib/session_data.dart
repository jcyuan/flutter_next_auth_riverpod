import 'package:flutter_next_auth_core/core/utils/session_serializer.dart';

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
    if (json is Map<String, dynamic>) {
      return SessionData(
        user: SessionUser(
          id: json['id']!,
          nickname: json['nickname']!,
          email: json['email']!,
          image: json['image']!,
        ),
        roles: json['roles'] ?? [],
        loginType: json['loginType'],
        visitMode: json['visitMode'],
      );
    }
    return null;
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
