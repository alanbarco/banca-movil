import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/data/firestore_paths.dart';
import '../../domain/entities/interest.dart';
import '../../domain/entities/user_profile.dart';
import '../models/user_profile_model.dart';

class UserProfileDatasource {
  UserProfileDatasource(this._firestore);

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _firestore.collection(FirestorePaths.users).doc(uid);

  /// `null` solo cuando el servidor confirma que el perfil no existe: un
  /// "no existe" desde caché (p. ej. primer login sin red) se ignora para no
  /// mandar al cliente a completar un perfil que sí tiene.
  Stream<UserProfile?> watch(String uid) {
    return _doc(uid)
        .snapshots()
        .where((snap) => snap.exists || !snap.metadata.isFromCache)
        .map((snap) => UserProfileModel.fromMap(uid, snap.data()));
  }

  Future<void> updateInterests(String uid, List<Interest> interests) {
    return _doc(uid).update({
      UserProfileModel.interests: [for (final i in interests) i.wireName],
      UserProfileModel.updatedAt: FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateNotificationsEnabled(String uid, {required bool enabled}) {
    return _doc(uid).update({
      '${UserProfileModel.preferences}.${UserProfileModel.notificationsEnabled}':
          enabled,
      UserProfileModel.updatedAt: FieldValue.serverTimestamp(),
    });
  }
}
