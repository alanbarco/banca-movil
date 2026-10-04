import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../entities/conversion.dart';

/// Convierte montos con tasas de base USD (`contracts/fx-external-api.md`).
///
/// Las tres fórmulas (USD → X, X → USD, X → Y) son el mismo cálculo si la
/// tasa de USD es 1: `monto ÷ tasa(origen) × tasa(destino)`.
class ConvertCurrency {
  const ConvertCurrency();

  static const base = 'USD';

  /// Divisas que no usan decimales.
  static const zeroDecimals = {'JPY'};

  Result<Conversion> call({
    required double amount,
    required String from,
    required String to,
    required Map<String, double> rates,
  }) {
    if (amount.isNaN || amount < 0) {
      return const Err(Failure.validation('amount'));
    }
    final fromRate = _rateOf(from, rates);
    final toRate = _rateOf(to, rates);
    if (fromRate == null || toRate == null || fromRate <= 0) {
      return const Err(Failure.validation('currency'));
    }

    final rate = toRate / fromRate;
    return Success(Conversion(amount: _round(amount * rate, to), rate: rate));
  }

  static double? _rateOf(String code, Map<String, double> rates) =>
      code == base ? 1 : rates[code];

  static double _round(double value, String currency) {
    final decimals = zeroDecimals.contains(currency) ? 0 : 2;
    final factor = decimals == 0 ? 1 : 100;
    return (value * factor).round() / factor;
  }
}
