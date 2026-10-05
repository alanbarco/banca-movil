/// Activa o desactiva las push del cliente. Lo implementa la feature
/// `notifications`; el perfil (`auth`) lo usa sin depender de ella.
abstract interface class NotificationsToggle {
  /// `false` si el sistema no concedió el permiso: no se activa nada.
  Future<bool> setEnabled({required bool enabled});
}
