import '../../../../core/data/data_snapshot.dart';
import '../../../../core/data/load_status.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/account.dart';
import '../../domain/usecases/watch_accounts.dart';
import 'live_data_cubit.dart';

/// Cuentas del cliente para el resumen del inicio (FR-009).
class AccountsCubit extends LiveDataCubit<List<Account>> {
  AccountsCubit({
    required WatchAccounts watchAccounts,
    required super.currentUser,
    required super.connectivity,
    required super.observability,
    super.staleGrace,
  }) : _watchAccounts = watchAccounts,
       super(feature: 'accounts');

  final WatchAccounts _watchAccounts;

  @override
  Stream<Result<DataSnapshot<List<Account>?>>> watch(String uid) {
    return _watchAccounts(uid).map(
      (result) => result.map(
        (snapshot) => snapshot.map<List<Account>?>(
          (accounts) => accounts.isEmpty ? null : accounts,
        ),
      ),
    );
  }

  @override
  LoadState<List<Account>> whenMissing() => const LoadState.empty();
}
