import '../entities/push_message.dart';

enum PushPermission { granted, denied, notDetermined }

/// Notificaciones push (FR-023 a FR-026).
///
/// El registro del dispositivo (token y topics) sigue la sesión: se hace al
/// iniciar sesión si el cliente las activó y se deshace al cerrar sesión.
abstract interface class NotificationsRepository {
  Future<PushPermission> permission();

  /// Muestra el diálogo del sistema (Android 13+).
  Future<PushPermission> requestPermission();

  /// Guarda la preferencia del cliente y registra o da de baja el
  /// dispositivo. Activar sin permiso concedido no registra nada.
  Future<void> setEnabled({required bool enabled});

  /// Llegadas con la app abierta (aviso in-app, FR-025).
  Stream<PushMessage> get foregroundMessages;

  /// Tocadas con la app en segundo plano.
  Stream<PushMessage> get openedMessages;

  /// La que abrió la app desde cerrada, si hubo una.
  Future<PushMessage?> initialMessage();
}
