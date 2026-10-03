import 'package:equatable/equatable.dart';

enum MovementType {
  credit,
  debit;

  static MovementType? fromWire(Object? value) {
    for (final type in values) {
      if (type.name == value) return type;
    }
    return null;
  }
}

/// Movimiento de una cuenta (`…/accounts/{accountId}/movements/{id}`).
class Movement extends Equatable {
  const Movement({
    required this.id,
    required this.date,
    required this.description,
    required this.amountCents,
    required this.type,
    required this.balanceAfterCents,
  });

  final String id;
  final DateTime date;
  final String description;

  /// Siempre positivo; el sentido lo da [type].
  final int amountCents;
  final MovementType type;
  final int balanceAfterCents;

  bool get isCredit => type == MovementType.credit;

  /// Monto con signo: positivo si es ingreso, negativo si es egreso.
  int get signedAmountCents => isCredit ? amountCents : -amountCents;

  @override
  List<Object?> get props => [
    id,
    date,
    description,
    amountCents,
    type,
    balanceAfterCents,
  ];
}

/// Página de movimientos y si quedan más por pedir.
class MovementPage extends Equatable {
  const MovementPage({required this.items, required this.hasMore});

  final List<Movement> items;
  final bool hasMore;

  @override
  List<Object?> get props => [items, hasMore];
}
