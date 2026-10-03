/// Estado de sesión que el router necesita para decidir a dónde ir.
enum SessionStatus {
  /// Aún no se sabe (arranque): la app se queda en `/splash`.
  unknown,
  unauthenticated,

  /// Autenticado en Firebase Auth pero sin perfil en Firestore (el
  /// aprovisionamiento falló): debe completar el onboarding.
  needsOnboarding,
  authenticated,
}

/// Contrato implementado por la feature `auth` (`AuthBloc`).
abstract interface class SessionStatusSource {
  SessionStatus get status;

  Stream<SessionStatus> get changes;
}

/// Fuente usada mientras ninguna feature registre la suya: la sesión nunca
/// se resuelve y la app permanece en `/splash`.
class UnresolvedSessionStatusSource implements SessionStatusSource {
  const UnresolvedSessionStatusSource();

  @override
  SessionStatus get status => SessionStatus.unknown;

  @override
  Stream<SessionStatus> get changes => const Stream.empty();
}
