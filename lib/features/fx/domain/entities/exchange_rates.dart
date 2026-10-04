import 'package:equatable/equatable.dart';

/// Tasas publicadas por el proveedor externo (`contracts/fx-external-api.md`).
///
/// La frescura (caché o servidor) viaja en `DataSnapshot`, igual que en
/// cuentas; aquí solo van los datos.
class ExchangeRates extends Equatable {
  const ExchangeRates({
    required this.base,
    required this.date,
    required this.rates,
    required this.fetchedAt,
  });

  final String base;

  /// Fecha de publicación de las tasas (FR-019).
  final DateTime date;

  /// Divisa → unidades por 1 [base].
  final Map<String, double> rates;

  /// Cuándo se descargaron.
  final DateTime fetchedAt;

  /// [base] primero y luego las divisas publicadas, en orden alfabético.
  List<String> get currencies => [base, ...rates.keys.toList()..sort()];

  @override
  List<Object?> get props => [base, date, rates, fetchedAt];
}
