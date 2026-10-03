import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/movement.dart';

/// `…/accounts/{accountId}/movements/{movementId}` ↔ [Movement].
abstract final class MovementModel {
  /// `null` si el documento no cumple el contrato.
  static Movement? fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) return null;
    final date = data['date'];
    final description = data['description'];
    final amount = data['amountCents'];
    final type = MovementType.fromWire(data['type']);
    final balanceAfter = data['balanceAfterCents'];
    if (date is! Timestamp ||
        description is! String ||
        amount is! num ||
        type == null ||
        balanceAfter is! num) {
      return null;
    }
    return Movement(
      id: doc.id,
      date: date.toDate(),
      description: description,
      amountCents: amount.toInt(),
      type: type,
      balanceAfterCents: balanceAfter.toInt(),
    );
  }
}
