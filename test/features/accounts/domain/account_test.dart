import 'package:bi_app/features/accounts/domain/entities/account.dart';
import 'package:bi_app/features/accounts/domain/entities/movement.dart';
import 'package:flutter_test/flutter_test.dart';

import '../accounts_fixtures.dart';

void main() {
  group('Account', () {
    test('maskedNumber muestra solo los últimos 4 dígitos', () {
      expect(savings.maskedNumber, '•••• 7890');
      expect(savings.lastFour, '7890');
    });

    test('números cortos no fallan', () {
      const account = Account(
        id: 'a',
        type: AccountType.checking,
        number: '12',
        balanceCents: 0,
      );
      expect(account.maskedNumber, '•••• 12');
    });

    test('AccountType.fromWire reconoce solo el catálogo', () {
      expect(AccountType.fromWire('savings'), AccountType.savings);
      expect(AccountType.fromWire('checking'), AccountType.checking);
      expect(AccountType.fromWire('credit'), isNull);
    });
  });

  group('Movement', () {
    test('isCredit y monto con signo según el tipo', () {
      final credit = movement(1, type: MovementType.credit, amountCents: 2500);
      final debit = movement(2, type: MovementType.debit, amountCents: 1000);

      expect(credit.isCredit, isTrue);
      expect(credit.signedAmountCents, 2500);
      expect(debit.isCredit, isFalse);
      expect(debit.signedAmountCents, -1000);
    });

    test('MovementType.fromWire reconoce solo el catálogo', () {
      expect(MovementType.fromWire('credit'), MovementType.credit);
      expect(MovementType.fromWire('debit'), MovementType.debit);
      expect(MovementType.fromWire('refund'), isNull);
    });
  });
}
