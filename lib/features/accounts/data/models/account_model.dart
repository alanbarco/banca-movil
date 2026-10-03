import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/account.dart';

/// `users/{uid}/accounts/{accountId}` ↔ [Account].
abstract final class AccountModel {
  /// `null` si el documento no cumple el contrato (se omite, no rompe la
  /// lista).
  static Account? fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) return null;
    final type = AccountType.fromWire(data['type']);
    final number = data['number'];
    final balance = data['balanceCents'];
    if (type == null || number is! String || balance is! num) return null;
    return Account(
      id: doc.id,
      type: type,
      number: number,
      currency: data['currency'] as String? ?? 'USD',
      balanceCents: balance.toInt(),
      openedAt: _date(data['openedAt']),
      updatedAt: _date(data['updatedAt']),
    );
  }

  static DateTime? _date(Object? value) =>
      value is Timestamp ? value.toDate() : null;
}
