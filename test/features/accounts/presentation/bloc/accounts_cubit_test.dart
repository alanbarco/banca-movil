import 'dart:async';

import 'package:bi_app/core/data/data_snapshot.dart';
import 'package:bi_app/core/data/load_status.dart';
import 'package:bi_app/core/error/failure.dart';
import 'package:bi_app/core/error/result.dart';
import 'package:bi_app/core/observability/analytics_events.dart';
import 'package:bi_app/features/accounts/domain/entities/account.dart';
import 'package:bi_app/features/accounts/domain/repositories/accounts_repository.dart';
import 'package:bi_app/features/accounts/presentation/bloc/account_detail_cubit.dart';
import 'package:bi_app/features/accounts/presentation/bloc/accounts_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fake_connectivity.dart';
import '../../../../helpers/fake_observability.dart';
import '../../accounts_fixtures.dart';

class _MockRepository extends Mock implements AccountsRepository {}

typedef _AccountsResult = Result<DataSnapshot<List<Account>>>;

void main() {
  final synced = DateTime.utc(2026, 10, 3, 9);
  late _MockRepository repository;
  late StreamController<_AccountsResult> source;
  late FakeObservabilityService observability;
  late FakeCurrentUser currentUser;
  late FakeConnectivity connectivity;
  const grace = Duration(milliseconds: 50);

  _AccountsResult fresh(List<Account> accounts) =>
      Success(DataSnapshot(data: accounts, lastSyncedAt: synced));

  _AccountsResult cached(List<Account> accounts, {DateTime? lastSyncedAt}) =>
      Success(
        DataSnapshot(data: accounts, isStale: true, lastSyncedAt: lastSyncedAt),
      );

  setUp(() {
    repository = _MockRepository();
    source = StreamController<_AccountsResult>.broadcast();
    observability = FakeObservabilityService();
    currentUser = FakeCurrentUser();
    connectivity = FakeConnectivity();
    when(() => repository.watchAccounts(uid)).thenAnswer((_) => source.stream);
  });

  tearDown(() => source.close());

  AccountsCubit build() => AccountsCubit(
    repository: repository,
    currentUser: currentUser,
    connectivity: connectivity,
    observability: observability,
    staleGrace: grace,
  );

  blocTest<AccountsCubit, Object>(
    'loading → success con las cuentas del servidor',
    build: build,
    act: (cubit) async {
      cubit.start();
      source.add(fresh([savings]));
    },
    expect: () => [
      const LoadState<List<Account>>.loading(),
      LoadState.success([savings]),
    ],
  );

  blocTest<AccountsCubit, Object>(
    'caché confirmada por el servidor a tiempo: sin aviso de desactualizado',
    build: build,
    act: (cubit) async {
      cubit.start();
      source.add(cached([savings], lastSyncedAt: synced));
      await pumpEventQueue();
      source.add(fresh([savings]));
      await Future<void>.delayed(grace * 2);
    },
    expect: () => [
      const LoadState<List<Account>>.loading(),
      LoadState.success([savings]),
    ],
    verify: (_) =>
        expect(observability.named(AnalyticsEvents.staleDataShown), isEmpty),
  );

  blocTest<AccountsCubit, Object>(
    'caché sin confirmar tras la espera → stale',
    build: build,
    act: (cubit) async {
      cubit.start();
      source.add(cached([savings], lastSyncedAt: synced));
      await Future<void>.delayed(grace * 2);
    },
    expect: () => [
      const LoadState<List<Account>>.loading(),
      LoadState.success([savings]),
      LoadState.stale([savings], lastSyncedAt: synced),
    ],
  );

  blocTest<AccountsCubit, Object>(
    'sin conexión: caché → stale inmediato con un único stale_data_shown',
    build: () {
      connectivity.setOnline(false);
      return build();
    },
    act: (cubit) async {
      cubit.start();
      source
        ..add(cached([savings], lastSyncedAt: synced))
        ..add(cached([savings], lastSyncedAt: synced));
      await pumpEventQueue();
      source.add(fresh([savings]));
    },
    expect: () => [
      const LoadState<List<Account>>.loading(),
      LoadState.stale([savings], lastSyncedAt: synced),
      LoadState.success([savings]),
    ],
    verify: (_) {
      final events = observability.named(AnalyticsEvents.staleDataShown);
      expect(events, hasLength(1));
      expect(events.single.parameters, {AnalyticsParams.feature: 'accounts'});
    },
  );

  blocTest<AccountsCubit, Object>(
    'sin cuentas confirmado por el servidor → empty',
    build: build,
    act: (cubit) async {
      cubit.start();
      source.add(fresh(const []));
    },
    expect: () => [
      const LoadState<List<Account>>.loading(),
      const LoadState<List<Account>>.empty(),
    ],
  );

  blocTest<AccountsCubit, Object>(
    'caché vacía no se muestra como empty: sigue cargando',
    build: build,
    act: (cubit) async {
      cubit.start();
      source.add(cached(const []));
    },
    expect: () => [const LoadState<List<Account>>.loading()],
  );

  blocTest<AccountsCubit, Object>(
    'caché vacía y servidor callado: error con reintento; luego llegan datos',
    build: build,
    act: (cubit) async {
      cubit.start();
      source.add(cached(const []));
      await Future<void>.delayed(grace * 2);
      source.add(fresh([savings]));
    },
    expect: () => [
      const LoadState<List<Account>>.loading(),
      const LoadState<List<Account>>.failure(Failure.network()),
      LoadState<List<Account>>.success([savings]),
    ],
  );

  blocTest<AccountsCubit, Object>(
    'falla → failure con data_load_error y retry vuelve a cargar',
    build: build,
    act: (cubit) async {
      cubit.start();
      source.add(const Err(Failure.network()));
      await pumpEventQueue();
      cubit.retry();
      source.add(fresh([savings]));
    },
    expect: () => [
      const LoadState<List<Account>>.loading(),
      const LoadState<List<Account>>.failure(Failure.network()),
      const LoadState<List<Account>>.loading(),
      LoadState.success([savings]),
    ],
    verify: (_) {
      expect(
        observability.named(AnalyticsEvents.dataLoadError).single.parameters,
        {
          AnalyticsParams.feature: 'accounts',
          AnalyticsParams.reason: 'network',
        },
      );
    },
  );

  blocTest<AccountsCubit, Object>(
    'falla con datos previos los conserva',
    build: build,
    act: (cubit) async {
      cubit.start();
      source.add(fresh([savings]));
      await pumpEventQueue();
      source.add(const Err(Failure.timeout()));
    },
    skip: 2,
    expect: () => [
      LoadState<List<Account>>.failure(
        const Failure.timeout(),
        previous: [savings],
      ),
    ],
  );

  blocTest<AccountsCubit, Object>(
    'sin usuario en sesión → unauthorized sin consultar',
    build: () {
      currentUser.current = null;
      return build();
    },
    act: (cubit) => cubit.start(),
    expect: () => [
      const LoadState<List<Account>>.failure(Failure.unauthorized()),
    ],
    verify: (_) => verifyNever(() => repository.watchAccounts(any())),
  );

  group('AccountDetailCubit', () {
    late StreamController<Result<DataSnapshot<Account?>>> detail;

    setUp(() {
      detail = StreamController.broadcast();
      when(
        () => repository.watchAccount(uid, 'acc-1'),
      ).thenAnswer((_) => detail.stream);
    });

    tearDown(() => detail.close());

    AccountDetailCubit buildDetail() => AccountDetailCubit(
      accountId: 'acc-1',
      repository: repository,
      currentUser: currentUser,
      connectivity: connectivity,
      observability: observability,
    );

    blocTest<AccountDetailCubit, Object>(
      'el saldo se actualiza en vivo',
      build: buildDetail,
      act: (cubit) async {
        const updated = Account(
          id: 'acc-1',
          type: AccountType.savings,
          number: '1234567890',
          balanceCents: 127500,
        );
        cubit.start();
        detail.add(Success(DataSnapshot<Account?>(data: savings)));
        await pumpEventQueue();
        detail.add(const Success(DataSnapshot<Account?>(data: updated)));
      },
      expect: () => [
        const LoadState<Account>.loading(),
        LoadState.success(savings),
        isA<LoadState<Account>>().having(
          (s) => s.data?.balanceCents,
          'balanceCents',
          127500,
        ),
      ],
    );

    blocTest<AccountDetailCubit, Object>(
      'cuenta inexistente → notFound',
      build: buildDetail,
      act: (cubit) async {
        cubit.start();
        detail.add(const Success(DataSnapshot<Account?>(data: null)));
      },
      expect: () => [
        const LoadState<Account>.loading(),
        const LoadState<Account>.failure(Failure.notFound()),
      ],
    );

    test('cerrar el cubit cancela la suscripción', () async {
      final cubit = buildDetail()..start();
      expect(detail.hasListener, isTrue);

      await cubit.close();

      expect(detail.hasListener, isFalse);
      expect(cubit.state.status, LoadStatus.loading);
    });
  });
}
