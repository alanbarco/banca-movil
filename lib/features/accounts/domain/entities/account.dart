import 'package:equatable/equatable.dart';

enum AccountType {
  savings,
  checking;

  static AccountType? fromWire(Object? value) {
    for (final type in values) {
      if (type.name == value) return type;
    }
    return null;
  }
}

/// Cuenta del cliente (`users/{uid}/accounts/{accountId}`).
class Account extends Equatable {
  const Account({
    required this.id,
    required this.type,
    required this.number,
    required this.balanceCents,
    this.currency = 'USD',
    this.openedAt,
    this.updatedAt,
  });

  final String id;
  final AccountType type;

  /// 10 dígitos; en la UI solo se muestran los últimos 4.
  final String number;
  final String currency;
  final int balanceCents;

  /// `null` mientras el `serverTimestamp` del alta no llega del servidor.
  final DateTime? openedAt;
  final DateTime? updatedAt;

  String get lastFour =>
      number.length <= 4 ? number : number.substring(number.length - 4);

  String get maskedNumber => '•••• $lastFour';

  @override
  List<Object?> get props => [
    id,
    type,
    number,
    currency,
    balanceCents,
    openedAt,
    updatedAt,
  ];
}
