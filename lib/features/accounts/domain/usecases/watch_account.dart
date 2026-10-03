import '../../../../core/data/data_snapshot.dart';
import '../../../../core/error/result.dart';
import '../entities/account.dart';
import '../repositories/accounts_repository.dart';

class WatchAccount {
  const WatchAccount(this._repository);

  final AccountsRepository _repository;

  Stream<Result<DataSnapshot<Account?>>> call(String uid, String accountId) =>
      _repository.watchAccount(uid, accountId);
}
