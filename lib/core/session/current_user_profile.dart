import 'package:equatable/equatable.dart';

/// Datos mínimos del cliente que otras features necesitan (sin PII).
class SessionUser extends Equatable {
  const SessionUser({
    required this.uid,
    required this.segment,
    this.interests = const [],
    this.notificationsEnabled = false,
  });

  final String uid;
  final String segment;
  final List<String> interests;

  /// El cliente activó las notificaciones push en su perfil.
  final bool notificationsEnabled;

  @override
  List<Object?> get props => [uid, segment, interests, notificationsEnabled];
}

/// Contrato implementado por la feature `auth`; el resto solo depende de esto.
abstract interface class CurrentUserProfile {
  /// `null` mientras no haya sesión o el perfil no exista.
  Stream<SessionUser?> get user;

  SessionUser? get current;
}
