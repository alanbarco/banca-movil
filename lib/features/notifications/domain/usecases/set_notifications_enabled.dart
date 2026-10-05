import '../../../../core/notifications/notifications_toggle.dart';
import '../repositories/notifications_repository.dart';

/// Activar pide el permiso del sistema si aún no se decidió; si el cliente
/// lo niega, no se guarda nada. Desactivar no necesita permiso.
class SetNotificationsEnabled implements NotificationsToggle {
  const SetNotificationsEnabled(this._repository);

  final NotificationsRepository _repository;

  @override
  Future<bool> setEnabled({required bool enabled}) async {
    if (enabled) {
      var permission = await _repository.permission();
      if (permission == PushPermission.notDetermined) {
        permission = await _repository.requestPermission();
      }
      if (permission != PushPermission.granted) return false;
    }
    await _repository.setEnabled(enabled: enabled);
    return true;
  }
}
