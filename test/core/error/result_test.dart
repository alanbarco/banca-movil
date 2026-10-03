import 'package:bi_app/core/error/failure.dart';
import 'package:bi_app/core/error/result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Result', () {
    test('fold ejecuta la rama de éxito', () {
      const Result<int> result = Success(2);

      final value = result.fold((_) => 'error', (v) => 'ok $v');

      expect(value, 'ok 2');
    });

    test('fold ejecuta la rama de error', () {
      const Result<int> result = Err(Failure.network());

      final value = result.fold((f) => f.reason, (v) => 'ok $v');

      expect(value, 'network');
    });

    test('map transforma el valor y conserva la falla', () {
      const Result<int> ok = Success(2);
      const Result<int> err = Err(Failure.timeout());

      expect(ok.map((v) => v * 10), const Success(20));
      expect(err.map((v) => v * 10), const Err<int>(Failure.timeout()));
    });

    test('accesores de conveniencia', () {
      const Result<String> ok = Success('a');
      const Result<String> err = Err(Failure.server());

      expect(ok.isSuccess, isTrue);
      expect(ok.valueOrNull, 'a');
      expect(ok.failureOrNull, isNull);
      expect(err.isSuccess, isFalse);
      expect(err.valueOrNull, isNull);
      expect(err.failureOrNull, const Failure.server());
    });

    test('igualdad por valor', () {
      expect(const Success(1), const Success(1));
      expect(const Success(1), isNot(const Success(2)));
      expect(
        const Err<int>(Failure.validation('email')),
        const Err<int>(Failure.validation('email')),
      );
    });
  });

  group('Failure', () {
    test('validation compara por campo', () {
      expect(
        const Failure.validation('email'),
        const ValidationFailure('email'),
      );
      expect(
        const Failure.validation('email'),
        isNot(const Failure.validation('password')),
      );
    });

    test('variantes distintas no son iguales', () {
      expect(const Failure.network(), isNot(const Failure.timeout()));
    });

    test('unknown ignora la causa en la igualdad', () {
      expect(Failure.unknown(Exception('a')), Failure.unknown(Exception('b')));
    });

    test('reason no contiene PII y es estable', () {
      expect(
        [
          const Failure.network(),
          const Failure.timeout(),
          const Failure.unauthorized(),
          const Failure.notFound(),
          const Failure.validation('email'),
          const Failure.server(),
          const Failure.unknown(),
        ].map((f) => f.reason),
        [
          'network',
          'timeout',
          'unauthorized',
          'not_found',
          'validation',
          'server',
          'other',
        ],
      );
    });
  });
}
