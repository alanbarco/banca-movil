import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Tokens del cliente en `users/{uid}/devices/{token}` (envío personal, p. ej.
/// avisos de movimientos) y su preferencia `preferences.notificationsEnabled`.
class DevicesDatasource {
  DevicesDatasource(this._firestore);

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _user(String uid) =>
      _firestore.collection('users').doc(uid);

  DocumentReference<Map<String, dynamic>> _device(String uid, String token) =>
      _user(uid).collection('devices').doc(token);

  /// Crea el documento o actualiza `lastSeenAt` si ya existía.
  Future<void> save(String uid, String token) async {
    final device = _device(uid, token);
    final now = FieldValue.serverTimestamp();
    final existing = await device.get();
    await device.set({
      'platform': defaultTargetPlatform.name,
      if (!existing.exists) 'createdAt': now,
      'lastSeenAt': now,
    }, SetOptions(merge: true));
  }

  Future<void> delete(String uid, String token) => _device(uid, token).delete();

  Future<void> setPreference(String uid, {required bool enabled}) =>
      _user(uid).update({
        'preferences.notificationsEnabled': enabled,
        'updatedAt': FieldValue.serverTimestamp(),
      });
}
