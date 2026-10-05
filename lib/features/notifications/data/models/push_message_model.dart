import 'package:firebase_messaging/firebase_messaging.dart';

import '../../domain/entities/push_message.dart';

/// `RemoteMessage` de FCM → [PushMessage] (`contracts/push-notifications.md`).
abstract final class PushMessageModel {
  static PushMessage fromRemote(RemoteMessage message) => fromParts(
    title: message.notification?.title,
    body: message.notification?.body,
    data: message.data,
  );

  static PushMessage fromParts({
    required String? title,
    required String? body,
    required Map<String, dynamic> data,
  }) {
    final route = data['route'];
    return PushMessage(
      title: title ?? '',
      body: body ?? '',
      type: PushType.fromWire(data['type']),
      route: route is String && route.isNotEmpty ? route : null,
    );
  }
}
