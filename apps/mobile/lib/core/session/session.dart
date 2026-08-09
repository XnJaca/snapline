import 'dart:convert';

import '../../api/models/auth_membership_dto.dart';
import '../../api/models/auth_result_dto.dart';
import '../../api/models/auth_user_dto.dart';

/// La sesión del usuario tal como vive en el dispositivo.
///
/// `accessTokenExpiresAt` se calcula al recibir la respuesta y se guarda como
/// instante absoluto: `expiresInSeconds` es relativo al momento de emisión, y
/// después de un cierre de la app ese momento ya no se puede reconstruir.
class Session {
  const Session({
    required this.accessToken,
    required this.refreshToken,
    required this.accessTokenExpiresAt,
    required this.user,
    required this.membership,
    required this.memberships,
  });

  factory Session.fromAuthResult(AuthResultDto result, DateTime receivedAt) {
    return Session(
      accessToken: result.accessToken,
      refreshToken: result.refreshToken,
      accessTokenExpiresAt: receivedAt.add(
        Duration(seconds: result.expiresInSeconds.toInt()),
      ),
      user: result.user,
      membership: result.membership,
      memberships: result.memberships,
    );
  }

  factory Session.fromJson(Map<String, Object?> json) {
    return Session(
      accessToken: json['accessToken']! as String,
      refreshToken: json['refreshToken']! as String,
      accessTokenExpiresAt: DateTime.parse(
        json['accessTokenExpiresAt']! as String,
      ),
      user: AuthUserDto.fromJson(json['user']! as Map<String, Object?>),
      membership: AuthMembershipDto.fromJson(
        json['membership']! as Map<String, Object?>,
      ),
      memberships: (json['memberships']! as List<Object?>)
          .map((e) => AuthMembershipDto.fromJson(e! as Map<String, Object?>))
          .toList(),
    );
  }

  factory Session.decode(String raw) =>
      Session.fromJson(jsonDecode(raw) as Map<String, Object?>);

  final String accessToken;
  final String refreshToken;
  final DateTime accessTokenExpiresAt;
  final AuthUserDto user;

  /// La membresía a la que quedó scopeado el token.
  final AuthMembershipDto membership;

  /// Todas las activas. Hoy no se usan: existen para no tener que migrar el
  /// almacenamiento cuando llegue el cambio de empresa. Ver SPEC-0001.
  final List<AuthMembershipDto> memberships;

  bool get isAccessTokenExpired =>
      DateTime.now().isAfter(accessTokenExpiresAt);

  Session copyWith({
    String? accessToken,
    String? refreshToken,
    DateTime? accessTokenExpiresAt,
  }) {
    return Session(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      accessTokenExpiresAt: accessTokenExpiresAt ?? this.accessTokenExpiresAt,
      user: user,
      membership: membership,
      memberships: memberships,
    );
  }

  Map<String, Object?> toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'accessTokenExpiresAt': accessTokenExpiresAt.toIso8601String(),
    'user': user.toJson(),
    'membership': membership.toJson(),
    'memberships': memberships.map((m) => m.toJson()).toList(),
  };

  String encode() => jsonEncode(toJson());

  /// Sin tokens a propósito: esto termina en logs y en reportes de error.
  @override
  String toString() =>
      'Session(user: ${user.id}, company: ${membership.companyId})';
}
