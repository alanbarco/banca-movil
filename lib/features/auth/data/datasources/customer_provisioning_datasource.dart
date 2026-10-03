import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/data/firestore_paths.dart';
import '../../domain/entities/onboarding_seed.dart';
import '../../domain/entities/registration_data.dart';
import '../models/user_profile_model.dart';

/// Crea, en un único `WriteBatch` atómico, el perfil, la cuenta de ahorros y
/// los movimientos de ejemplo (FR-004, ADR-002).
///
/// Las Security Rules solo aceptan cuentas y movimientos dentro de este batch
/// (el perfil no existía antes y existirá después).
class CustomerProvisioningDatasource {
  CustomerProvisioningDatasource(this._firestore, {Random? random})
    : _random = random ?? Random.secure();

  final FirebaseFirestore _firestore;
  final Random _random;

  Future<void> provision({
    required String uid,
    required String email,
    required RegistrationData data,
    required OnboardingSeed seed,
    DateTime? now,
  }) {
    final batch = _firestore.batch();
    final userRef = _firestore.collection(FirestorePaths.users).doc(uid);
    batch.set(userRef, UserProfileModel.toCreateMap(email: email, data: data));

    final accountRef = userRef.collection(FirestorePaths.accounts).doc();
    batch.set(accountRef, {
      'type': seed.accountType,
      'number': generateAccountNumber(),
      'currency': 'USD',
      'balanceCents': seed.initialBalanceCents,
      'openedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final movements = accountRef.collection(FirestorePaths.movements);
    for (final movement in seed.plan(now ?? DateTime.now())) {
      batch.set(movements.doc(), {
        'date': Timestamp.fromDate(movement.date),
        'description': movement.description,
        'amountCents': movement.amountCents,
        'type': movement.isCredit ? 'credit' : 'debit',
        'balanceAfterCents': movement.balanceAfterCents,
      });
    }
    return batch.commit();
  }

  /// Número de cuenta de 10 dígitos (en la UI solo se muestran los últimos 4).
  String generateAccountNumber() =>
      List.generate(10, (_) => _random.nextInt(10)).join();
}
