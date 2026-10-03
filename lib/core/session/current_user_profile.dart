import 'package:equatable/equatable.dart';

/// Datos mínimos del cliente que otras features necesitan (sin PII).
class SessionUser extends Equatable {
  const SessionUser({
    required this.uid,
    required this.segment,
    this.interests = const [],
  });

  final String uid;
  final String segment;
  final List<String> interests;

  @override
  List<Object?> get props => [uid, segment, interests];
}

/// Contrato implementado por la feature `auth`; el resto solo depende de esto.
abstract interface class CurrentUserProfile {
  /// `null` mientras no haya sesión o el perfil no exista.
  Stream<SessionUser?> get user;

  SessionUser? get current;
}
