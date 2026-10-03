import '../../../../core/data/data_snapshot.dart';
import '../../../../core/data/load_status.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/account.dart';
import '../../domain/usecases/watch_account.dart';
import 'live_data_cubit.dart';

/// Encabezado del detalle: la cuenta con su saldo en vivo (FR-012).
class AccountDetailCubit extends LiveDataCubit<Account> {
  AccountDetailCubit({
    required this.accountId,
    required WatchAccount watchAccount,
    required super.currentUser,
    required super.connectivity,
    required super.observability,
    super.staleGrace,
  }) : _watchAccount = watchAccount,
       super(feature: 'account_detail');

  final String accountId;
  final WatchAccount _watchAccount;

  @override
  Stream<Result<DataSnapshot<Account?>>> watch(String uid) =>
      _watchAccount(uid, accountId);

  @override
  LoadState<Account> whenMissing() =>
      const LoadState.failure(Failure.notFound());
}
