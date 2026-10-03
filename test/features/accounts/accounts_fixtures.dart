import 'package:bi_app/core/session/current_user_profile.dart';
import 'package:bi_app/features/accounts/domain/entities/account.dart';
import 'package:bi_app/features/accounts/domain/entities/movement.dart';

const uid = 'uid-ana';

final savings = Account(
  id: 'acc-1',
  type: AccountType.savings,
  number: '1234567890',
  balanceCents: 125000,
  openedAt: DateTime.utc(2026, 9, 1),
  updatedAt: DateTime.utc(2026, 10, 3),
);

/// Movimiento `n` días antes del 3 de octubre de 2026 (más reciente = menor).
Movement movement(
  int n, {
  MovementType type = MovementType.credit,
  int amountCents = 1000,
}) {
  return Movement(
    id: 'mov-${n.toString().padLeft(3, '0')}',
    date: DateTime.utc(2026, 10, 3).subtract(Duration(hours: n)),
    description: 'Movimiento $n',
    amountCents: amountCents,
    type: type,
    balanceAfterCents: 100000 + n,
  );
}

List<Movement> movements(int from, int count) => [
  for (var i = from; i < from + count; i++) movement(i),
];

/// `CurrentUserProfile` fijo para cubits que necesitan el `uid`.
class FakeCurrentUser implements CurrentUserProfile {
  FakeCurrentUser([
    this.current = const SessionUser(uid: uid, segment: 'student'),
  ]);

  @override
  SessionUser? current;

  @override
  Stream<SessionUser?> get user => Stream.value(current);
}
