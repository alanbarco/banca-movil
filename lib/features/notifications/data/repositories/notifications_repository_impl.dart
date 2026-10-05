import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/observability/app_logger.dart';
import '../../../../core/session/current_user_profile.dart';
import '../../../../core/session/session_events.dart';
import '../../domain/entities/push_message.dart';
import '../../domain/repositories/notifications_repository.dart';
import '../datasources/devices_datasource.dart';
import '../datasources/fcm_datasource.dart';

/// Registro del dispositivo según la sesión (`contracts/push-notifications.md`):
///
/// - `SignedIn` con push activadas y permiso concedido: guarda el token y
///   suscribe a `all` y `segment_<segmento>`.
/// - `SegmentChanged`: cambia de topic de segmento.
/// - Cierre de sesión: da de baja topics, borra el token de Firestore y lo
///   invalida (FR-008), antes de perder las credenciales.
class NotificationsRepositoryImpl implements NotificationsRepository {
  NotificationsRepositoryImpl({
    required FcmDatasource fcm,
    required DevicesDatasource devices,
    required SessionEvents sessionEvents,
    required CurrentUserProfile currentUser,
    AppLogger? logger,
  }) : _fcm = fcm,
       _devices = devices,
       _currentUser = currentUser,
       _logger = logger ?? AppLogger('notifications') {
    _subscriptions
      ..add(sessionEvents.stream.listen(_onSessionEvent))
      ..add(_fcm.tokenRefresh.listen(_onTokenRefresh));
    sessionEvents.addSignOutCleanup(_unregister);
  }

  static const topicAll = 'all';
  static String segmentTopic(String segment) => 'segment_$segment';

  final FcmDatasource _fcm;
  final DevicesDatasource _devices;
  final CurrentUserProfile _currentUser;
  final AppLogger _logger;
  final List<StreamSubscription<Object?>> _subscriptions = [];

  /// Registro vigente; `null` si este dispositivo no recibe push.
  _Registration? _registration;

  @override
  Future<PushPermission> permission() => _fcm.permission();

  @override
  Future<PushPermission> requestPermission() => _fcm.requestPermission();

  @override
  Stream<PushMessage> get foregroundMessages => _fcm.foregroundMessages;

  @override
  Stream<PushMessage> get openedMessages => _fcm.openedMessages;

  @override
  Future<PushMessage?> initialMessage() => _fcm.initialMessage();

  @override
  Future<void> setEnabled({required bool enabled}) async {
    final user = _currentUser.current;
    if (user == null) return;
    await _devices.setPreference(user.uid, enabled: enabled);
    if (enabled) {
      await _register(user.uid, user.segment);
    } else {
      await _unregister(user.uid);
    }
  }

  Future<void> _onSessionEvent(SessionEvent event) async {
    switch (event) {
      case SignedIn(:final uid, :final segment):
        if (_currentUser.current?.notificationsEnabled ?? false) {
          await _register(uid, segment);
        }
      case SegmentChanged(:final oldSegment, :final newSegment):
        final registration = _registration;
        if (registration == null) return;
        await _safely('cambio de segmento', () async {
          await _fcm.unsubscribe(segmentTopic(oldSegment));
          await _fcm.subscribe(segmentTopic(newSegment));
          _registration = registration.copyWith(segment: newSegment);
        });
      case SigningOut():
        // Lo hace `_unregister`, que `auth` espera antes de cerrar sesión.
        break;
    }
  }

  Future<void> _register(String uid, String segment) async {
    if (await _fcm.permission() != PushPermission.granted) return;
    await _safely('registro', () async {
      final token = await _fcm.token();
      if (token == null) return;
      await _devices.save(uid, token);
      await _fcm.subscribe(topicAll);
      await _fcm.subscribe(segmentTopic(segment));
      _registration = _Registration(uid: uid, token: token, segment: segment);
      _logger.info('dispositivo registrado para push', {'segment': segment});
      // Solo en debug: para "Enviar mensaje de prueba" en la consola de
      // Firebase. El logger lo redactaría (y en release no debe salir).
      if (kDebugMode) debugPrint('FCM token: $token');
    });
  }

  Future<void> _unregister(String uid) async {
    final registration = _registration;
    if (registration == null || registration.uid != uid) return;
    _registration = null;
    await _safely('baja', () async {
      await _fcm.unsubscribe(topicAll);
      await _fcm.unsubscribe(segmentTopic(registration.segment));
      await _devices.delete(uid, registration.token);
      await _fcm.deleteToken();
    });
  }

  Future<void> _onTokenRefresh(String token) async {
    final registration = _registration;
    if (registration == null) return;
    await _safely('token renovado', () async {
      await _devices.save(registration.uid, token);
      _registration = registration.copyWith(token: token);
    });
  }

  /// Un fallo de push nunca debe romper la sesión ni la navegación.
  Future<void> _safely(String step, Future<void> Function() action) async {
    try {
      await action();
    } on Object catch (error) {
      _logger.warning('push: falló $step', {'error': '$error'});
    }
  }

  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
  }
}

class _Registration {
  const _Registration({
    required this.uid,
    required this.token,
    required this.segment,
  });

  final String uid;
  final String token;
  final String segment;

  _Registration copyWith({String? token, String? segment}) => _Registration(
    uid: uid,
    token: token ?? this.token,
    segment: segment ?? this.segment,
  );
}
