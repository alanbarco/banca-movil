import 'package:equatable/equatable.dart';

/// Movimiento de ejemplo definido en Remote Config (`onboarding_seed`).
class SeedMovement extends Equatable {
  const SeedMovement({
    required this.description,
    required this.amountCents,
    required this.isCredit,
    required this.daysAgo,
  });

  final String description;
  final int amountCents;
  final bool isCredit;
  final int daysAgo;

  int get signedAmountCents => isCredit ? amountCents : -amountCents;

  @override
  List<Object?> get props => [description, amountCents, isCredit, daysAgo];
}

/// Movimiento listo para escribirse, con fecha y saldo resultante.
class PlannedMovement extends Equatable {
  const PlannedMovement({
    required this.description,
    required this.amountCents,
    required this.isCredit,
    required this.date,
    required this.balanceAfterCents,
  });

  final String description;
  final int amountCents;
  final bool isCredit;
  final DateTime date;
  final int balanceAfterCents;

  @override
  List<Object?> get props => [
    description,
    amountCents,
    isCredit,
    date,
    balanceAfterCents,
  ];
}

/// Cuenta y movimientos que se crean al completar el registro (FR-004).
class OnboardingSeed extends Equatable {
  const OnboardingSeed({
    required this.accountType,
    required this.initialBalanceCents,
    required this.movements,
  });

  // Límites de las Security Rules: cada documento del batch usa 2 accesos
  // (máx. 20 por batch) y los montos están acotados.
  static const maxMovements = 8;
  static const maxBalanceCents = 1000000;
  static const maxMovementCents = 500000;
  static const descriptionMax = 60;

  /// `null` si el JSON no respeta el contrato o las reglas lo rechazarían.
  static OnboardingSeed? fromJson(Map<String, dynamic> json) {
    final account = json['account'];
    final rawMovements = json['movements'];
    if (account is! Map<String, dynamic> || rawMovements is! List) return null;

    final type = account['type'];
    final balance = account['initialBalanceCents'];
    if (type is! String ||
        !const ['savings', 'checking'].contains(type) ||
        balance is! int ||
        balance < 0 ||
        balance > maxBalanceCents ||
        rawMovements.length > maxMovements) {
      return null;
    }

    final movements = <SeedMovement>[];
    for (final raw in rawMovements) {
      if (raw is! Map<String, dynamic>) return null;
      final description = raw['description'];
      final amount = raw['amountCents'];
      final movementType = raw['type'];
      final daysAgo = raw['daysAgo'];
      if (description is! String ||
          description.isEmpty ||
          description.length > descriptionMax ||
          amount is! int ||
          amount <= 0 ||
          amount > maxMovementCents ||
          (movementType != 'credit' && movementType != 'debit') ||
          daysAgo is! int ||
          daysAgo < 0) {
        return null;
      }
      movements.add(
        SeedMovement(
          description: description,
          amountCents: amount,
          isCredit: movementType == 'credit',
          daysAgo: daysAgo,
        ),
      );
    }

    final seed = OnboardingSeed(
      accountType: type,
      initialBalanceCents: balance,
      movements: movements,
    );
    // Ningún saldo intermedio puede quedar negativo.
    final balances = seed
        .plan(DateTime.utc(2000))
        .map((m) => m.balanceAfterCents);
    if (seed.openingBalanceCents < 0 || balances.any((b) => b < 0)) return null;
    return seed;
  }

  final String accountType;
  final int initialBalanceCents;
  final List<SeedMovement> movements;

  /// Saldo antes del primer movimiento, de modo que tras el último el saldo
  /// sea exactamente [initialBalanceCents].
  int get openingBalanceCents =>
      initialBalanceCents -
      movements.fold(0, (sum, m) => sum + m.signedAmountCents);

  /// Movimientos ordenados del más antiguo al más reciente, con su saldo.
  List<PlannedMovement> plan(DateTime now) {
    final ordered = [...movements]
      ..sort((a, b) => b.daysAgo.compareTo(a.daysAgo));
    var balance = openingBalanceCents;
    return [
      for (final movement in ordered)
        PlannedMovement(
          description: movement.description,
          amountCents: movement.amountCents,
          isCredit: movement.isCredit,
          // Margen de un minuto: las reglas exigen `date <= request.time`.
          date: now.subtract(Duration(days: movement.daysAgo, minutes: 1)),
          balanceAfterCents: balance += movement.signedAmountCents,
        ),
    ];
  }

  @override
  List<Object?> get props => [accountType, initialBalanceCents, movements];
}
