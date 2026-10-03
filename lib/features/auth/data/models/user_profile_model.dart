import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/interest.dart';
import '../../domain/entities/registration_data.dart';
import '../../domain/entities/segment.dart';
import '../../domain/entities/user_profile.dart';

/// Conversión entre `users/{uid}` y [UserProfile].
abstract final class UserProfileModel {
  static const fullName = 'fullName';
  static const email = 'email';
  static const segment = 'segment';
  static const interests = 'interests';
  static const preferences = 'preferences';
  static const notificationsEnabled = 'notificationsEnabled';
  static const termsVersion = 'termsVersion';
  static const termsAcceptedAt = 'termsAcceptedAt';
  static const createdAt = 'createdAt';
  static const updatedAt = 'updatedAt';

  /// `null` si faltan campos esenciales o tienen valores fuera del catálogo.
  static UserProfile? fromMap(String uid, Map<String, dynamic>? map) {
    if (map == null) return null;
    final name = map[fullName];
    final mail = map[email];
    final parsedSegment = Segment.fromWire(map[segment]);
    final rawInterests = map[interests];
    if (name is! String || mail is! String || parsedSegment == null) {
      return null;
    }
    final prefs = map[preferences];
    return UserProfile(
      uid: uid,
      fullName: name,
      email: mail,
      segment: parsedSegment,
      interests: rawInterests is List
          ? rawInterests.map(Interest.fromWire).whereType<Interest>().toList()
          : const [],
      notificationsEnabled: prefs is Map && prefs[notificationsEnabled] == true,
      termsVersion: map[termsVersion] as String?,
      termsAcceptedAt: _toDate(map[termsAcceptedAt]),
      createdAt: _toDate(map[createdAt]),
    );
  }

  /// Documento de creación; las fechas las pone el servidor (`request.time`).
  static Map<String, Object?> toCreateMap({
    required String email,
    required RegistrationData data,
  }) {
    return {
      fullName: data.fullName.trim(),
      UserProfileModel.email: email,
      segment: data.segment.wireName,
      interests: [for (final i in data.interests) i.wireName],
      preferences: {notificationsEnabled: false},
      termsVersion: data.termsVersion,
      termsAcceptedAt: FieldValue.serverTimestamp(),
      createdAt: FieldValue.serverTimestamp(),
    };
  }

  static DateTime? _toDate(Object? value) =>
      value is Timestamp ? value.toDate() : null;
}
