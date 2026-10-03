import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/data/data_snapshot.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/fault_injection/fault_config.dart';
import '../../../../core/fault_injection/fault_runner.dart';
import '../../../../core/observability/app_logger.dart';
import '../../../../core/observability/observability_service.dart';
import '../../domain/entities/account.dart';
import '../../domain/entities/movement.dart';
import '../../domain/repositories/accounts_repository.dart';
import '../datasources/accounts_firestore_datasource.dart';
import '../datasources/last_sync_store.dart';
import '../models/account_model.dart';
import '../models/movement_model.dart';

/// Cuentas y movimientos desde Firestore, con frescura de datos y el
/// simulador de fallos aplicado (FR-028, FR-032).
class AccountsRepositoryImpl implements AccountsRepository {
  AccountsRepositoryImpl({
    required AccountsFirestoreDatasource datasource,
    required LastSyncStore lastSync,
    required FaultRunner faults,
    required ObservabilityService observability,
    AppLogger? logger,
  }) : _datasource = datasource,
       _lastSync = lastSync,
       _faults = faults,
       _observability = observability,
       _logger = logger ?? AppLogger('accounts');

  final AccountsFirestoreDatasource _datasource;
  final LastSyncStore _lastSync;
  final FaultRunner _faults;
  final ObservabilityService _observability;
  final AppLogger _logger;

  /// Último documento de cada página, para `startAfterDocument`.
  final _cursors = <String, JsonDocumentSnapshot>{};

  @override
  Stream<Result<DataSnapshot<List<Account>>>> watchAccounts(String uid) {
    return _watch(
      uid: uid,
      operation: 'watch_accounts',
      source: () => _datasource.watchAccounts(uid),
      metadata: (snapshot) => snapshot.metadata,
      parse: (snapshot) =>
          snapshot.docs.map(AccountModel.fromDoc).nonNulls.toList(),
    );
  }

  @override
  Stream<Result<DataSnapshot<Account?>>> watchAccount(
    String uid,
    String accountId,
  ) {
    return _watch(
      uid: uid,
      operation: 'watch_account',
      source: () => _datasource.watchAccount(uid, accountId),
      metadata: (snapshot) => snapshot.metadata,
      parse: (snapshot) =>
          snapshot.exists ? AccountModel.fromDoc(snapshot) : null,
    );
  }

  @override
  Stream<Result<DataSnapshot<MovementPage>>> watchRecentMovements(
    String uid,
    String accountId,
  ) {
    return _watch(
      uid: uid,
      operation: 'watch_movements',
      source: () => _datasource.watchRecentMovements(
        uid,
        accountId,
        limit: AccountsRepository.pageSize,
      ),
      metadata: (snapshot) => snapshot.metadata,
      parse: (snapshot) => _page(accountId, snapshot),
    );
  }

  @override
  Future<Result<DataSnapshot<MovementPage>>> fetchMoreMovements(
    String uid,
    String accountId, {
    required Movement after,
  }) async {
    try {
      final snapshot = await _faults.runWithFaults(
        FaultTarget.firestore,
        () async {
          final cursor =
              _cursors[_cursorKey(accountId, after.id)] ??
              await _datasource.getMovement(uid, accountId, after.id);
          if (!cursor.exists) throw const _MissingCursor();
          return _datasource.fetchMovementsAfter(
            uid,
            accountId,
            cursor: cursor,
            limit: AccountsRepository.pageSize,
          );
        },
      );
      return Success(
        await _snapshot(uid, snapshot.metadata, _page(accountId, snapshot)),
      );
    } on Object catch (error, stackTrace) {
      return Err(_fail('fetch_more_movements', error, stackTrace));
    }
  }

  MovementPage _page(String accountId, JsonQuerySnapshot snapshot) {
    final docs = snapshot.docs;
    if (docs.isNotEmpty) {
      _cursors[_cursorKey(accountId, docs.last.id)] = docs.last;
    }
    return MovementPage(
      items: docs.map(MovementModel.fromDoc).nonNulls.toList(),
      hasMore: docs.length == AccountsRepository.pageSize,
    );
  }

  static String _cursorKey(String accountId, String movementId) =>
      '$accountId/$movementId';

  /// Convierte cada snapshot en `Success` y cada error en `Err`; el stream
  /// nunca emite errores.
  Stream<Result<DataSnapshot<T>>> _watch<S, T>({
    required String uid,
    required String operation,
    required Stream<S> Function() source,
    required SnapshotMetadata Function(S snapshot) metadata,
    required T Function(S snapshot) parse,
  }) {
    return _faults
        .streamWithFaults(FaultTarget.firestore, source)
        .asyncMap<Result<DataSnapshot<T>>>(
          (snapshot) async => Success(
            await _snapshot(uid, metadata(snapshot), parse(snapshot)),
          ),
        )
        .transform(
          StreamTransformer.fromHandlers(
            handleError: (error, stackTrace, sink) =>
                sink.add(Err(_fail(operation, error, stackTrace))),
          ),
        );
  }

  /// Datos de caché quedan marcados `isStale` con la última sincronización
  /// real; los del servidor actualizan esa hora.
  Future<DataSnapshot<T>> _snapshot<T>(
    String uid,
    SnapshotMetadata metadata,
    T data,
  ) async {
    final fromCache = metadata.isFromCache;
    return DataSnapshot(
      data: data,
      isStale: fromCache,
      lastSyncedAt: fromCache
          ? _lastSync.lastSyncedAt(uid)
          : await _lastSync.markSynced(uid),
    );
  }

  Failure _fail(String operation, Object error, StackTrace stackTrace) {
    final failure = mapError(error);
    _logger.warning('$operation falló', {'reason': failure.reason});
    final simulated = error is SimulatedFaultException;
    if (!simulated && (failure is UnknownFailure || failure is ServerFailure)) {
      unawaited(
        _observability.recordError(error, stackTrace, reason: operation),
      );
    }
    return failure;
  }

  static Failure mapError(Object error) {
    if (error is SimulatedFaultException) {
      return error.mode == FaultMode.offline
          ? const Failure.network()
          : const Failure.server();
    }
    if (error is FirebaseException) {
      return switch (error.code) {
        'unavailable' => const Failure.network(),
        'deadline-exceeded' => const Failure.timeout(),
        'permission-denied' ||
        'unauthenticated' => const Failure.unauthorized(),
        'not-found' => const Failure.notFound(),
        'resource-exhausted' => const Failure.server(),
        _ => Failure.unknown(error),
      };
    }
    if (error is TimeoutException) return const Failure.timeout();
    if (error is _MissingCursor) return const Failure.notFound();
    return Failure.unknown(error);
  }
}

/// El movimiento usado como cursor ya no existe.
class _MissingCursor implements Exception {
  const _MissingCursor();
}
