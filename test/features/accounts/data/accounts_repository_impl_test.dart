import 'dart:async';

import 'package:bi_app/core/data/data_snapshot.dart';
import 'package:bi_app/core/error/failure.dart';
import 'package:bi_app/core/error/result.dart';
import 'package:bi_app/core/fault_injection/fault_config.dart';
import 'package:bi_app/core/fault_injection/fault_runner.dart';
import 'package:bi_app/core/storage/local_storage.dart';
import 'package:bi_app/features/accounts/data/datasources/accounts_firestore_datasource.dart';
import 'package:bi_app/features/accounts/data/datasources/last_sync_store.dart';
import 'package:bi_app/features/accounts/data/repositories/accounts_repository_impl.dart';
import 'package:bi_app/features/accounts/domain/entities/account.dart';
import 'package:bi_app/features/accounts/domain/repositories/accounts_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/fake_observability.dart';
import '../accounts_fixtures.dart';

class _MockQuerySnapshot extends Mock implements JsonQuerySnapshot {}

class _MockMetadata extends Mock implements SnapshotMetadata {}

/// Fake de Firestore que puede responder "desde caché" o fallar.
class _Datasource extends AccountsFirestoreDatasource {
  _Datasource(super.firestore);

  bool fromCache = false;
  Object? error;

  @override
  Stream<JsonQuerySnapshot> watchAccounts(String uid) {
    final failure = error;
    if (failure != null) return Stream.error(failure);
    return super.watchAccounts(uid).map(_maybeCached);
  }

  JsonQuerySnapshot _maybeCached(JsonQuerySnapshot real) {
    if (!fromCache) return real;
    final metadata = _MockMetadata();
    when(() => metadata.isFromCache).thenReturn(true);
    final snapshot = _MockQuerySnapshot();
    when(() => snapshot.docs).thenReturn(real.docs);
    when(() => snapshot.metadata).thenReturn(metadata);
    return snapshot;
  }
}

class _Faults implements FaultConfigSource {
  FaultConfig config = FaultConfig.normal;

  @override
  FaultConfig configFor(FaultTarget target) =>
      target == FaultTarget.firestore ? config : FaultConfig.normal;
}

void main() {
  final syncTime = DateTime.utc(2026, 10, 3, 15, 30);
  late FakeFirebaseFirestore firestore;
  late _Datasource datasource;
  late LocalStorage storage;
  late _Faults faults;
  late FakeObservabilityService observability;
  late AccountsRepositoryImpl repository;

  DocumentReference<Map<String, dynamic>> accountRef([String id = 'acc-1']) =>
      firestore.collection('users').doc(uid).collection('accounts').doc(id);

  Future<void> addAccount({String id = 'acc-1', int balance = 125000}) {
    return accountRef(id).set({
      'type': 'savings',
      'number': '1234567890',
      'currency': 'USD',
      'balanceCents': balance,
      'openedAt': Timestamp.fromDate(DateTime.utc(2026, 9)),
      'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 10, 3)),
    });
  }

  /// Movimientos `mov-000` (más reciente) … `mov-{count-1}`.
  Future<void> addMovements(int count) async {
    for (final m in movements(0, count)) {
      await accountRef().collection('movements').doc(m.id).set({
        'date': Timestamp.fromDate(m.date),
        'description': m.description,
        'amountCents': m.amountCents,
        'type': m.type.name,
        'balanceAfterCents': m.balanceAfterCents,
      });
    }
  }

  AccountsRepositoryImpl build() => AccountsRepositoryImpl(
    datasource: datasource,
    lastSync: LastSyncStore(storage, clock: () => syncTime),
    faults: FaultRunner(faults),
    observability: observability,
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = await LocalStorage.create();
    firestore = FakeFirebaseFirestore();
    datasource = _Datasource(firestore);
    faults = _Faults();
    observability = FakeObservabilityService();
    repository = build();
  });

  group('cuentas', () {
    test(
      'lee las cuentas del cliente y guarda la hora de sincronización',
      () async {
        await addAccount();

        final result = await repository.watchAccounts(uid).first;

        final snapshot = result.valueOrNull!;
        expect(snapshot.data.single.id, 'acc-1');
        expect(snapshot.data.single.type, AccountType.savings);
        expect(snapshot.data.single.balanceCents, 125000);
        expect(snapshot.data.single.maskedNumber, '•••• 7890');
        expect(snapshot.isStale, isFalse);
        expect(snapshot.lastSyncedAt, syncTime);
        expect(LastSyncStore(storage).lastSyncedAt(uid), syncTime);
      },
    );

    test(
      'datos de caché quedan stale con la última sincronización real',
      () async {
        await addAccount();
        await repository.watchAccounts(uid).first;
        datasource.fromCache = true;

        final snapshot = (await build().watchAccounts(uid).first).valueOrNull!;

        expect(snapshot.isStale, isTrue);
        expect(snapshot.lastSyncedAt, syncTime);
        expect(snapshot.data, hasLength(1));
      },
    );

    test('caché sin sincronización previa: stale sin hora', () async {
      datasource.fromCache = true;

      final snapshot = (await repository.watchAccounts(uid).first).valueOrNull!;

      expect(snapshot.isStale, isTrue);
      expect(snapshot.lastSyncedAt, isNull);
    });

    test(
      'documentos fuera de contrato se omiten sin romper la lista',
      () async {
        await addAccount();
        await accountRef('rota').set({'type': 'crypto', 'number': 1});

        final snapshot =
            (await repository.watchAccounts(uid).first).valueOrNull!;

        expect(snapshot.data.map((a) => a.id), ['acc-1']);
      },
    );

    test('watchAccount entrega null si la cuenta no existe', () async {
      final result = await repository.watchAccount(uid, 'nada').first;

      expect(result.valueOrNull!.data, isNull);
    });

    test('watchAccount refleja cambios de saldo en vivo', () async {
      await addAccount();
      final balances = repository
          .watchAccount(uid, 'acc-1')
          .map((r) => r.valueOrNull?.data?.balanceCents);
      final received = <int?>[];
      final subscription = balances.listen(received.add);
      await pumpEventQueue();

      await accountRef().update({'balanceCents': 127500});
      await pumpEventQueue();

      expect(received, containsAllInOrder([125000, 127500]));
      await subscription.cancel();
    });
  });

  group('movimientos', () {
    test('primera página: 20 más recientes por fecha descendente', () async {
      await addAccount();
      await addMovements(25);

      final page = (await repository.watchRecentMovements(uid, 'acc-1').first)
          .valueOrNull!
          .data;

      expect(page.items, hasLength(AccountsRepository.pageSize));
      expect(page.items.first.id, 'mov-000');
      expect(page.items.last.id, 'mov-019');
      expect(page.hasMore, isTrue);
      final dates = page.items.map((m) => m.date).toList();
      final newestFirst = <DateTime>[...dates]..sort((a, b) => b.compareTo(a));
      expect(dates, orderedEquals(newestFirst));
    });

    test('menos de una página: hasMore es false', () async {
      await addAccount();
      await addMovements(3);

      final page = (await repository.watchRecentMovements(uid, 'acc-1').first)
          .valueOrNull!
          .data;

      expect(page.items, hasLength(3));
      expect(page.hasMore, isFalse);
    });

    test('paginación con startAfterDocument sin repetir ni saltar', () async {
      await addAccount();
      await addMovements(25);
      final first = (await repository.watchRecentMovements(uid, 'acc-1').first)
          .valueOrNull!
          .data;

      final next = await repository.fetchMoreMovements(
        uid,
        'acc-1',
        after: first.items.last,
      );

      final page = next.valueOrNull!.data;
      expect(page.items.map((m) => m.id), [
        for (var i = 20; i < 25; i++) 'mov-${i.toString().padLeft(3, '0')}',
      ]);
      expect(page.hasMore, isFalse);
    });

    test('paginación sin cursor en memoria lo busca en Firestore', () async {
      await addAccount();
      await addMovements(25);

      final next = await build().fetchMoreMovements(
        uid,
        'acc-1',
        after: movement(19),
      );

      expect(next.valueOrNull!.data.items.first.id, 'mov-020');
    });

    test('cursor inexistente → notFound', () async {
      await addAccount();

      final next = await repository.fetchMoreMovements(
        uid,
        'acc-1',
        after: movement(99),
      );

      expect(next.failureOrNull, const Failure.notFound());
    });

    test('movimiento nuevo aparece primero en el stream en vivo', () async {
      await addAccount();
      await addMovements(3);
      final firstIds = <String>[];
      final subscription = repository.watchRecentMovements(uid, 'acc-1').listen(
        (r) {
          final items = r.valueOrNull?.data.items;
          if (items != null && items.isNotEmpty) firstIds.add(items.first.id);
        },
      );
      await pumpEventQueue();

      await accountRef().collection('movements').doc('nuevo').set({
        'date': Timestamp.fromDate(DateTime.utc(2026, 10, 4)),
        'description': 'Pago',
        'amountCents': 2500,
        'type': 'credit',
        'balanceAfterCents': 127500,
      });
      await pumpEventQueue();

      expect(firstIds.first, 'mov-000');
      expect(firstIds.last, 'nuevo');
      await subscription.cancel();
    });
  });

  group('errores y simulador', () {
    test('error de Firestore llega como Err y no como excepción', () async {
      datasource.error = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );

      final results = await repository.watchAccounts(uid).toList();

      expect(results, [
        const Err<DataSnapshot<List<Account>>>(Failure.unauthorized()),
      ]);
      expect(observability.errors, isEmpty);
    });

    test('error desconocido se reporta a Crashlytics', () async {
      datasource.error = StateError('boom');

      final result = await repository.watchAccounts(uid).first;

      expect(result.failureOrNull, isA<UnknownFailure>());
      expect(observability.errors, hasLength(1));
    });

    test('simulador en modo error: como el SDK, entrega lo disponible', () async {
      // El cubit del simulador corta la red real (`disableNetwork`) y Firestore
      // responde desde su caché; el repositorio no recibe un error.
      await addAccount();
      faults.config = const FaultConfig(mode: FaultMode.error);

      final result = await repository.watchAccounts(uid).first;

      expect(result.isSuccess, isTrue);
      expect(observability.errors, isEmpty);
    });

    test('un fallo simulado se traduce sin reportar a Crashlytics', () {
      expect(
        AccountsRepositoryImpl.mapError(
          const SimulatedFaultException(FaultTarget.firestore, FaultMode.error),
        ),
        const Failure.server(),
      );
      expect(
        AccountsRepositoryImpl.mapError(
          const SimulatedFaultException(
            FaultTarget.firestore,
            FaultMode.offline,
          ),
        ),
        const Failure.network(),
      );
    });

    test('simulador en modo latencia retrasa la primera entrega', () async {
      await addAccount();
      faults.config = const FaultConfig(mode: FaultMode.latency, latencyMs: 50);
      final watch = Stopwatch()..start();

      final result = await repository.watchAccounts(uid).first;

      expect(result.isSuccess, isTrue);
      expect(watch.elapsedMilliseconds, greaterThanOrEqualTo(50));
    });

    test('mapError traduce los códigos de Firestore', () {
      Failure map(String code) => AccountsRepositoryImpl.mapError(
        FirebaseException(plugin: 'cloud_firestore', code: code),
      );

      expect(map('unavailable'), const Failure.network());
      expect(map('deadline-exceeded'), const Failure.timeout());
      expect(map('unauthenticated'), const Failure.unauthorized());
      expect(map('not-found'), const Failure.notFound());
      expect(map('resource-exhausted'), const Failure.server());
      expect(
        AccountsRepositoryImpl.mapError(TimeoutException('lento')),
        const Failure.timeout(),
      );
      expect(
        AccountsRepositoryImpl.mapError(
          const SimulatedFaultException(
            FaultTarget.firestore,
            FaultMode.offline,
          ),
        ),
        const Failure.network(),
      );
    });
  });
}
