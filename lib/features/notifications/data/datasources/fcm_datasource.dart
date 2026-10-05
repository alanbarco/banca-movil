import 'package:firebase_messaging/firebase_messaging.dart';

import '../../domain/entities/push_message.dart';
import '../../domain/repositories/notifications_repository.dart';
import '../models/push_message_model.dart';

/// Envoltorio delgado de Firebase Cloud Messaging.
class FcmDatasource {
  FcmDatasource([FirebaseMessaging? messaging])
    : _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseMessaging _messaging;

  Future<PushPermission> permission() async =>
      _map((await _messaging.getNotificationSettings()).authorizationStatus);

  Future<PushPermission> requestPermission() async =>
      _map((await _messaging.requestPermission()).authorizationStatus);

  Future<String?> token() => _messaging.getToken();

  Stream<String> get tokenRefresh => _messaging.onTokenRefresh;

  Future<void> deleteToken() => _messaging.deleteToken();

  Future<void> subscribe(String topic) => _messaging.subscribeToTopic(topic);

  Future<void> unsubscribe(String topic) =>
      _messaging.unsubscribeFromTopic(topic);

  Stream<PushMessage> get foregroundMessages =>
      FirebaseMessaging.onMessage.map(PushMessageModel.fromRemote);

  Stream<PushMessage> get openedMessages =>
      FirebaseMessaging.onMessageOpenedApp.map(PushMessageModel.fromRemote);

  Future<PushMessage?> initialMessage() async {
    final message = await _messaging.getInitialMessage();
    return message == null ? null : PushMessageModel.fromRemote(message);
  }

  static PushPermission _map(AuthorizationStatus status) => switch (status) {
    AuthorizationStatus.authorized ||
    AuthorizationStatus.provisional => PushPermission.granted,
    AuthorizationStatus.denied ||
    AuthorizationStatus.deniedPermanently => PushPermission.denied,
    AuthorizationStatus.notDetermined => PushPermission.notDetermined,
  };
}
