import 'package:equatable/equatable.dart';

/// Resultado del conversor: monto ya redondeado y tasa efectiva usada
/// (FR-020).
class Conversion extends Equatable {
  const Conversion({required this.amount, required this.rate});

  final double amount;

  /// Unidades de la divisa destino por 1 de la divisa origen.
  final double rate;

  @override
  List<Object?> get props => [amount, rate];
}
