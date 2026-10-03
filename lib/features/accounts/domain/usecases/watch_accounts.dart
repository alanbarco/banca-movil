import '../../../../core/data/data_snapshot.dart';
import '../../../../core/error/result.dart';
import '../entities/account.dart';
import '../repositories/accounts_repository.dart';

class WatchAccounts {
  const WatchAccounts(this._repository);

  final AccountsRepository _repository;

  Stream<Result<DataSnapshot<List<Account>>>> call(String uid) =>
      _repository.watchAccounts(uid);
}
