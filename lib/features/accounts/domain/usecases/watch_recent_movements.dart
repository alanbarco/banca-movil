import '../../../../core/data/data_snapshot.dart';
import '../../../../core/error/result.dart';
import '../entities/movement.dart';
import '../repositories/accounts_repository.dart';

class WatchRecentMovements {
  const WatchRecentMovements(this._repository);

  final AccountsRepository _repository;

  Stream<Result<DataSnapshot<MovementPage>>> call(
    String uid,
    String accountId,
  ) => _repository.watchRecentMovements(uid, accountId);
}
