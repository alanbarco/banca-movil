import 'package:bi_app/core/error/failure.dart';
import 'package:bi_app/features/fx/domain/entities/conversion.dart';
import 'package:bi_app/features/fx/domain/usecases/convert_currency.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Tasas con base USD, como las devuelve Frankfurter.
  const rates = {'EUR': 0.92, 'MXN': 18.4, 'JPY': 149.57};
  const convert = ConvertCurrency();

  Conversion ok(
    double amount,
    String from,
    String to, [
    Map<String, double>? r,
  ]) => convert(
    amount: amount,
    from: from,
    to: to,
    rates: r ?? rates,
  ).valueOrNull!;

  group('ConvertCurrency', () {
    test('USD → X multiplica por la tasa', () {
      final result = ok(100, 'USD', 'EUR');

      expect(result.amount, 92.0);
      expect(result.rate, 0.92);
    });

    test('X → USD divide por la tasa', () {
      final result = ok(92, 'EUR', 'USD');

      expect(result.amount, 100.0);
      expect(result.rate, closeTo(1 / 0.92, 1e-9));
    });

    test('X → Y pasa por USD', () {
      final result = ok(100, 'EUR', 'MXN');

      expect(result.amount, 2000.0);
      expect(result.rate, closeTo(18.4 / 0.92, 1e-9));
    });

    test('misma divisa: tasa 1', () {
      final result = ok(50, 'EUR', 'EUR');

      expect(result.amount, 50.0);
      expect(result.rate, 1.0);
    });

    test('redondea a 2 decimales', () {
      final result = ok(1, 'USD', 'MXN', const {'MXN': 18.4567});

      expect(result.amount, 18.46);
    });

    test('JPY va sin decimales', () {
      final result = ok(10, 'USD', 'JPY');

      expect(result.amount, 1496.0); // 1495.7 → 1496
    });

    test('divisa sin tasa es inválida', () {
      final result = convert(amount: 10, from: 'USD', to: 'COP', rates: rates);

      expect(result.failureOrNull, const Failure.validation('currency'));
    });

    test('monto negativo es inválido', () {
      final result = convert(amount: -1, from: 'USD', to: 'EUR', rates: rates);

      expect(result.failureOrNull, const Failure.validation('amount'));
    });
  });
}
