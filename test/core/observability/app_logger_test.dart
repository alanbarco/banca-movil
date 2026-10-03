import 'package:bi_app/core/observability/app_logger.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppLogger.redact', () {
    test('enmascara correos', () {
      expect(
        AppLogger.redact('login de ana.perez+test@correo.com.ec falló'),
        'login de [email] falló',
      );
    });

    test('enmascara montos con símbolo o con decimales', () {
      expect(AppLogger.redact(r'saldo $1,250.00 ok'), 'saldo [monto] ok');
      expect(AppLogger.redact('pago USD 45.5'), 'pago [monto]');
      expect(AppLogger.redact('monto 1.250,00'), 'monto [monto]');
      expect(AppLogger.redact('transferí 300,50 hoy'), 'transferí [monto] hoy');
    });

    test('enmascara números de 8 o más dígitos', () {
      expect(
        AppLogger.redact('cuenta 2201345678 y cédula 0912345678'),
        'cuenta [numero] y cédula [numero]',
      );
      expect(AppLogger.redact('id 12345678'), 'id [numero]');
    });

    test('conserva números cortos, fechas y texto sin PII', () {
      const text = 'reintento 3 de 3 · 2026-10-03 10:45 · status 503';
      expect(AppLogger.redact(text), text);
    });
  });

  group('AppLogger', () {
    late List<LogRecord> records;
    late AppLogger logger;

    setUp(() {
      records = [];
      logger = AppLogger('test', sink: records.add);
    });

    test('redacta mensaje, valores de campos y error', () {
      logger.error(
        'fallo para cliente@bi.com',
        error: Exception('cuenta 2201345678'),
        fields: {'feature': 'accounts', 'detail': r'saldo $10.00'},
      );

      final record = records.single;
      expect(record.message, 'fallo para [email]');
      expect(record.fields, {'feature': 'accounts', 'detail': 'saldo [monto]'});
      expect(record.error, contains('[numero]'));
      expect(record.error, isNot(contains('2201345678')));
    });

    test('oculta por completo los campos con nombre sensible', () {
      logger.info('registro', {
        'email': 'a@b.co',
        'fullName': 'Ana Pérez',
        'balanceCents': 125000,
        'accountNumber': '2201',
        'password': 'secreta1',
        'step': 'terms',
        'online': false,
      });

      expect(records.single.fields, {
        'email': AppLogger.redactedValue,
        'fullName': AppLogger.redactedValue,
        'balanceCents': AppLogger.redactedValue,
        'accountNumber': AppLogger.redactedValue,
        'password': AppLogger.redactedValue,
        'step': 'terms',
        'online': false,
      });
    });

    test('descarta niveles por debajo del mínimo', () {
      final quiet = AppLogger(
        'quiet',
        sink: records.add,
        minLevel: LogLevel.warning,
      );

      quiet
        ..debug('d')
        ..info('i')
        ..warning('w');

      expect(records.map((r) => r.level), [LogLevel.warning]);
    });

    test('toString incluye nivel, logger, campos y error', () {
      logger.warning('lento', {'ms': 900});

      expect(records.single.toString(), '[WARNING] test: lento ms=900');
    });
  });
}
