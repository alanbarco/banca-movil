import 'package:intl/intl.dart';

import '../../../core/error/failure.dart';
import '../domain/usecases/convert_currency.dart';

abstract final class FxTexts {
  static const title = 'Divisas';
  static const converterTitle = 'Conversor';
  static const amountLabel = 'Monto';
  static const fromLabel = 'De';
  static const toLabel = 'A';
  static const swap = 'Intercambiar divisas';
  static const ratesTitle = 'Tipos de cambio';
  static const loading = 'Cargando tipos de cambio';
  static const invalidAmount = 'Ingresa un monto válido';
  static const unavailableCause = 'Servicio de divisas no disponible';
  static const source = 'Fuente: Banco Central Europeo (Frankfurter)';

  /// El resto de la app sigue funcionando (FR-022).
  static String loadError(Failure failure) => switch (failure) {
    NetworkFailure() || TimeoutFailure() =>
      'No pudimos conectarnos al servicio de tipos de cambio. '
          'Revisa tu conexión e inténtalo de nuevo.',
    _ =>
      'El servicio de tipos de cambio no está disponible en este momento. '
          'El resto de la app sigue funcionando.',
  };

  static String ratesDate(DateTime date) =>
      'Tasas del ${DateFormat('dd/MM/yyyy').format(date)}';

  static String amount(double value, String currency) {
    final digits = ConvertCurrency.zeroDecimals.contains(currency) ? 0 : 2;
    return '${_number(value, digits)} $currency';
  }

  /// Tasa efectiva usada en la conversión (FR-020).
  static String rateUsed(double rate, String from, String to) =>
      'Tasa usada: 1 $from = ${_number(rate, 4)} $to';

  static String rate(double rate) => _number(rate, 4);

  static String _number(double value, int digits) =>
      NumberFormat.decimalPatternDigits(
        locale: 'es',
        decimalDigits: digits,
      ).format(value);
}
