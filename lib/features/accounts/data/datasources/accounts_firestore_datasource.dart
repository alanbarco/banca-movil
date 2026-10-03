import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/data/firestore_paths.dart';

typedef JsonQuerySnapshot = QuerySnapshot<Map<String, dynamic>>;
typedef JsonDocumentSnapshot = DocumentSnapshot<Map<String, dynamic>>;

/// Consultas de cuentas y movimientos.
///
/// Los listeners usan `includeMetadataChanges` para enterarse de cuándo los
/// datos pasan de caché a confirmados por el servidor (FR-028).
class AccountsFirestoreDatasource {
  AccountsFirestoreDatasource(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _accounts(String uid) => _firestore
      .collection(FirestorePaths.users)
      .doc(uid)
      .collection(FirestorePaths.accounts);

  CollectionReference<Map<String, dynamic>> _movements(
    String uid,
    String accountId,
  ) => _accounts(uid).doc(accountId).collection(FirestorePaths.movements);

  Query<Map<String, dynamic>> _byDateDesc(String uid, String accountId) =>
      _movements(uid, accountId).orderBy('date', descending: true);

  Stream<JsonQuerySnapshot> watchAccounts(String uid) =>
      _accounts(uid).snapshots(includeMetadataChanges: true);

  Stream<JsonDocumentSnapshot> watchAccount(String uid, String accountId) =>
      _accounts(uid).doc(accountId).snapshots(includeMetadataChanges: true);

  Stream<JsonQuerySnapshot> watchRecentMovements(
    String uid,
    String accountId, {
    required int limit,
  }) => _byDateDesc(
    uid,
    accountId,
  ).limit(limit).snapshots(includeMetadataChanges: true);

  Future<JsonQuerySnapshot> fetchMovementsAfter(
    String uid,
    String accountId, {
    required JsonDocumentSnapshot cursor,
    required int limit,
  }) =>
      _byDateDesc(uid, accountId).startAfterDocument(cursor).limit(limit).get();

  Future<JsonDocumentSnapshot> getMovement(
    String uid,
    String accountId,
    String movementId,
  ) => _movements(uid, accountId).doc(movementId).get();
}
