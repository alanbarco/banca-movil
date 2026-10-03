import '../../../../core/data/data_snapshot.dart';
import '../../../../core/error/result.dart';
import '../entities/movement.dart';
import '../repositories/accounts_repository.dart';

class FetchMoreMovements {
  const FetchMoreMovements(this._repository);

  final AccountsRepository _repository;

  Future<Result<DataSnapshot<MovementPage>>> call(
    String uid,
    String accountId, {
    required Movement after,
  }) => _repository.fetchMoreMovements(uid, accountId, after: after);
}
