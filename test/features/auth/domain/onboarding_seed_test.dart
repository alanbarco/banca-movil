import 'package:bi_app/features/auth/domain/entities/interest.dart';
import 'package:bi_app/features/auth/domain/entities/onboarding_seed.dart';
import 'package:bi_app/features/auth/domain/entities/segment.dart';
import 'package:flutter_test/flutter_test.dart';

import '../auth_fixtures.dart';

Map<String, dynamic> _seed({
  Object? type = 'savings',
  Object? balance = 125000,
  List<Object?>? movements,
}) => {
  'schemaVersion': 1,
  'account': {'type': type, 'initialBalanceCents': balance},
  'movements': movements ?? contractSeedJson['movements'],
};

Map<String, dynamic> _movement({
  Object? description = 'Pago',
  Object? amount = 1000,
  Object? type = 'credit',
  Object? daysAgo = 1,
}) => {
  'description': description,
  'amountCents': amount,
  'type': type,
  'daysAgo': daysAgo,
};

void main() {
  group('OnboardingSeed.plan', () {
    final now = DateTime.utc(2026, 10, 3, 12);

    test('ordena del más antiguo al más reciente y cuadra con el saldo', () {
      final planned = contractSeed.plan(now);

      expect(planned.map((m) => m.description), [
        'Depósito de apertura',
        'Transferencia recibida',
        'Supermercado',
      ]);
      expect(planned.map((m) => m.balanceAfterCents), [100000, 140000, 125000]);
      expect(planned.last.balanceAfterCents, contractSeed.initialBalanceCents);
      expect(contractSeed.openingBalanceCents, 0);
    });

    test('fechas = ahora − daysAgo con un minuto de margen', () {
      final planned = contractSeed.plan(now);

      expect(
        planned.first.date,
        now.subtract(const Duration(days: 10, minutes: 1)),
      );
      expect(planned.every((m) => m.date.isBefore(now)), isTrue);
    });
  });

  group('OnboardingSeed.fromJson', () {
    test('acepta la semilla del contrato', () {
      expect(contractSeed.accountType, 'savings');
      expect(contractSeed.movements, hasLength(3));
      expect(contractSeed.movements.last.isCredit, isFalse);
    });

    final invalid = <String, Map<String, dynamic>>{
      'sin cuenta': {'movements': <Object>[]},
      'tipo de cuenta desconocido': _seed(type: 'credit_card'),
      'saldo negativo': _seed(balance: -1),
      'saldo sobre el límite': _seed(balance: 1000001),
      'demasiados movimientos': _seed(
        balance: 9000,
        movements: List.generate(9, (_) => _movement()),
      ),
      'movimiento no objeto': _seed(movements: ['x']),
      'descripción vacía': _seed(movements: [_movement(description: '')]),
      'descripción larga': _seed(movements: [_movement(description: 'x' * 61)]),
      'monto cero': _seed(movements: [_movement(amount: 0)]),
      'monto sobre el límite': _seed(
        balance: 600000,
        movements: [_movement(amount: 500001)],
      ),
      'tipo de movimiento desconocido': _seed(
        movements: [_movement(type: 'refund')],
      ),
      'daysAgo negativo': _seed(movements: [_movement(daysAgo: -1)]),
      // 1000 de saldo pero un débito de 5000 sin fondos previos.
      'saldo intermedio negativo': _seed(
        balance: 1000,
        movements: [
          _movement(amount: 5000, type: 'debit', daysAgo: 5),
          _movement(amount: 6000, daysAgo: 1),
        ],
      ),
    };

    for (final MapEntry(key: name, value: json) in invalid.entries) {
      test('rechaza: $name', () {
        expect(OnboardingSeed.fromJson(json), isNull);
      });
    }
  });

  group('catálogos', () {
    test('Segment e Interest se leen desde Firestore', () {
      expect(Segment.fromWire('student'), Segment.student);
      expect(Segment.fromWire('vip'), isNull);
      expect(Interest.fromWire('travel'), Interest.travel);
      expect(Interest.fromWire(3), isNull);
      expect(Segment.entrepreneur.wireName, 'entrepreneur');
      expect(Interest.business.wireName, 'business');
    });

    test('UserProfile.firstName toma el primer nombre', () {
      expect(anaProfile.firstName, 'Ana');
    });
  });
}
