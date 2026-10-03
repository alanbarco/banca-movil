import '../../../../core/data/data_snapshot.dart';
import '../../../../core/error/result.dart';
import '../entities/account.dart';
import '../entities/movement.dart';

/// Lecturas en tiempo real de cuentas y movimientos (FR-009, FR-011, FR-012).
///
/// Los streams no terminan con error: cada falla llega como `Err` y el
/// llamador decide si vuelve a suscribirse.
abstract interface class AccountsRepository {
  /// Movimientos por página (FR-011).
  static const pageSize = 20;

  Stream<Result<DataSnapshot<List<Account>>>> watchAccounts(String uid);

  /// `data` es `null` si la cuenta no existe.
  Stream<Result<DataSnapshot<Account?>>> watchAccount(
    String uid,
    String accountId,
  );

  /// Los [pageSize] movimientos más recientes, actualizados en vivo.
  Stream<Result<DataSnapshot<MovementPage>>> watchRecentMovements(
    String uid,
    String accountId,
  );

  /// La página siguiente a [after] (orden por fecha descendente).
  Future<Result<DataSnapshot<MovementPage>>> fetchMoreMovements(
    String uid,
    String accountId, {
    required Movement after,
  });
}
