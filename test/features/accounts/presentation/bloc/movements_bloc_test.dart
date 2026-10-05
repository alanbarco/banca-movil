import 'dart:async';

import 'package:bi_app/core/data/data_snapshot.dart';
import 'package:bi_app/core/data/load_status.dart';
import 'package:bi_app/core/error/failure.dart';
import 'package:bi_app/core/error/result.dart';
import 'package:bi_app/core/observability/analytics_events.dart';
import 'package:bi_app/features/accounts/domain/entities/movement.dart';
import 'package:bi_app/features/accounts/domain/repositories/accounts_repository.dart';
import 'package:bi_app/features/accounts/presentation/bloc/movements_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fake_connectivity.dart';
import '../../../../helpers/fake_observability.dart';
import '../../accounts_fixtures.dart';

class _MockRepository extends Mock implements AccountsRepository {}

typedef _PageResult = Result<DataSnapshot<MovementPage>>;

Result<DataSnapshot<MovementPage>> livePage(
  List<Movement> items, {
  bool hasMore = false,
}) => Success(
  DataSnapshot(
    data: MovementPage(items: items, hasMore: hasMore),
  ),
);

void main() {
  late _MockRepository repository;
  late StreamController<_PageResult> live;
  late FakeObservabilityService observability;
  late FakeConnectivity connectivity;
  const grace = Duration(milliseconds: 50);

  setUpAll(() => registerFallbackValue(movement(0)));

  setUp(() {
    repository = _MockRepository();
    live = StreamController<_PageResult>.broadcast();
    observability = FakeObservabilityService();
    connectivity = FakeConnectivity();
    when(
      () => repository.watchRecentMovements(uid, 'acc-1'),
    ).thenAnswer((_) => live.stream);
  });

  tearDown(() => live.close());

  MovementsBloc build() => MovementsBloc(
    accountId: 'acc-1',
    repository: repository,
    currentUser: FakeCurrentUser(),
    connectivity: connectivity,
    observability: observability,
    staleGrace: grace,
  );

  _PageResult cachedPage(DateTime synced) => Success(
    DataSnapshot(
      data: MovementPage(items: movements(0, 3), hasMore: false),
      isStale: true,
      lastSyncedAt: synced,
    ),
  );

  /// Arranca el bloc y espera a que se suscriba al stream en vivo.
  Future<MovementsBloc> started() async {
    final bloc = build()..add(const MovementsStarted());
    await pumpEventQueue();
    return bloc;
  }

  List<String> ids(MovementsState state) =>
      state.items.map((m) => m.id).toList();

  test('primera página en vivo', () async {
    final bloc = await started();
    await pumpEventQueue();
    expect(bloc.state.status, LoadStatus.loading);

    live.add(livePage(movements(0, 20), hasMore: true));
    await pumpEventQueue();

    expect(bloc.state.status, LoadStatus.success);
    expect(bloc.state.items, hasLength(20));
    expect(bloc.state.hasMore, isTrue);
    await bloc.close();
  });

  test(
    'loadMore agrega la página siguiente usando el último como cursor',
    () async {
      when(
        () => repository.fetchMoreMovements(
          uid,
          'acc-1',
          after: any(named: 'after'),
        ),
      ).thenAnswer((_) async => livePage(movements(20, 5)));
      final bloc = await started();
      live.add(livePage(movements(0, 20), hasMore: true));
      await pumpEventQueue();

      bloc.add(const MovementsLoadMoreRequested());
      await pumpEventQueue();

      verify(
        () => repository.fetchMoreMovements(uid, 'acc-1', after: movement(19)),
      ).called(1);
      expect(bloc.state.items, hasLength(25));
      expect(bloc.state.hasMore, isFalse);
      expect(bloc.state.loadingMore, isFalse);
      await bloc.close();
    },
  );

  test('fin de la lista: no vuelve a pedir', () async {
    final bloc = await started();
    live.add(livePage(movements(0, 3)));
    await pumpEventQueue();

    bloc.add(const MovementsLoadMoreRequested());
    await pumpEventQueue();

    expect(bloc.state.hasMore, isFalse);
    verifyNever(
      () => repository.fetchMoreMovements(
        any(),
        any(),
        after: any(named: 'after'),
      ),
    );
    await bloc.close();
  });

  test('pedidos repetidos mientras carga se ignoran', () async {
    final pending = Completer<_PageResult>();
    when(
      () => repository.fetchMoreMovements(
        uid,
        'acc-1',
        after: any(named: 'after'),
      ),
    ).thenAnswer((_) => pending.future);
    final bloc = await started();
    live.add(livePage(movements(0, 20), hasMore: true));
    await pumpEventQueue();

    bloc
      ..add(const MovementsLoadMoreRequested())
      ..add(const MovementsLoadMoreRequested());
    await pumpEventQueue();
    expect(bloc.state.loadingMore, isTrue);
    pending.complete(livePage(movements(20, 20), hasMore: true));
    await pumpEventQueue();

    verify(
      () => repository.fetchMoreMovements(
        uid,
        'acc-1',
        after: any(named: 'after'),
      ),
    ).called(1);
    expect(bloc.state.items, hasLength(40));
    await bloc.close();
  });

  test('error al pedir más conserva la lista y permite reintentar', () async {
    when(
      () => repository.fetchMoreMovements(
        uid,
        'acc-1',
        after: any(named: 'after'),
      ),
    ).thenAnswer((_) async => const Err(Failure.network()));
    final bloc = await started();
    live.add(livePage(movements(0, 20), hasMore: true));
    await pumpEventQueue();

    bloc.add(const MovementsLoadMoreRequested());
    await pumpEventQueue();

    expect(bloc.state.items, hasLength(20));
    expect(bloc.state.status, LoadStatus.success);
    expect(bloc.state.loadMoreFailure, const Failure.network());
    expect(bloc.state.hasMore, isTrue);
    expect(observability.named(AnalyticsEvents.dataLoadError), hasLength(1));
    await bloc.close();
  });

  test('movimiento entrante aparece primero', () async {
    final bloc = await started();
    live.add(livePage(movements(1, 3)));
    await pumpEventQueue();

    final incoming = Movement(
      id: 'nuevo',
      date: DateTime.utc(2026, 10, 4),
      description: 'Pago',
      amountCents: 2500,
      type: MovementType.credit,
      balanceAfterCents: 127500,
    );
    live.add(livePage([incoming, ...movements(1, 3)]));
    await pumpEventQueue();

    expect(ids(bloc.state), ['nuevo', 'mov-001', 'mov-002', 'mov-003']);
    await bloc.close();
  });

  test('movimiento entrante con páginas extra no deja huecos', () async {
    when(
      () => repository.fetchMoreMovements(
        uid,
        'acc-1',
        after: any(named: 'after'),
      ),
    ).thenAnswer((_) async => livePage(movements(21, 5)));
    final bloc = await started();
    live.add(livePage(movements(1, 20), hasMore: true));
    await pumpEventQueue();
    bloc.add(const MovementsLoadMoreRequested());
    await pumpEventQueue();

    // mov-020 sale de la primera página al llegar el nuevo movimiento.
    live.add(livePage([movement(0), ...movements(1, 19)], hasMore: true));
    await pumpEventQueue();

    expect(ids(bloc.state), [
      for (var i = 0; i < 26; i++) 'mov-${i.toString().padLeft(3, '0')}',
    ]);
    await bloc.close();
  });

  test('sin movimientos → empty; caché vacía sigue cargando', () async {
    final bloc = await started();
    live.add(
      const Success(
        DataSnapshot(
          data: MovementPage(items: [], hasMore: false),
          isStale: true,
        ),
      ),
    );
    await pumpEventQueue();
    expect(bloc.state.status, LoadStatus.loading);

    live.add(livePage(const []));
    await pumpEventQueue();
    expect(bloc.state.status, LoadStatus.empty);
    await bloc.close();
  });

  test('caché vacía y servidor callado: error; luego llegan datos', () async {
    final bloc = await started();
    live.add(
      const Success(
        DataSnapshot(
          data: MovementPage(items: [], hasMore: false),
          isStale: true,
        ),
      ),
    );
    await Future<void>.delayed(grace * 2);
    await pumpEventQueue();
    expect(bloc.state.status, LoadStatus.failure);
    expect(bloc.state.failure, const Failure.network());

    live.add(livePage(movements(0, 3)));
    await pumpEventQueue();
    expect(bloc.state.status, LoadStatus.success);
    expect(bloc.state.failure, isNull);
    await bloc.close();
  });

  test('caché confirmada a tiempo: se muestra sin aviso', () async {
    final bloc = await started();
    live.add(cachedPage(DateTime.utc(2026, 10, 3, 9)));
    await pumpEventQueue();
    expect(bloc.state.status, LoadStatus.success);
    expect(bloc.state.items, hasLength(3));

    live.add(livePage(movements(0, 3)));
    await Future<void>.delayed(grace * 2);

    expect(bloc.state.status, LoadStatus.success);
    expect(observability.named(AnalyticsEvents.staleDataShown), isEmpty);
    await bloc.close();
  });

  test('caché sin confirmar tras la espera → stale', () async {
    final bloc = await started();
    live.add(cachedPage(DateTime.utc(2026, 10, 3, 9)));
    await pumpEventQueue();

    await Future<void>.delayed(grace * 2);

    expect(bloc.state.status, LoadStatus.stale);
    await bloc.close();
  });

  test('perder la conexión con datos de caché → stale al instante', () async {
    final bloc = await started();
    live.add(cachedPage(DateTime.utc(2026, 10, 3, 9)));
    await pumpEventQueue();

    connectivity.setOnline(false);
    await pumpEventQueue();

    expect(bloc.state.status, LoadStatus.stale);
    await bloc.close();
  });

  test('sin conexión: caché → stale con hora y stale_data_shown', () async {
    final synced = DateTime.utc(2026, 10, 3, 9);
    connectivity.setOnline(false);
    final bloc = await started();
    live.add(cachedPage(synced));
    await pumpEventQueue();

    expect(bloc.state.status, LoadStatus.stale);
    expect(bloc.state.lastSyncedAt, synced);
    expect(
      observability.named(AnalyticsEvents.staleDataShown).single.parameters,
      {AnalyticsParams.feature: 'movements'},
    );
    await bloc.close();
  });

  test('falla del stream → failure; reintentar vuelve a suscribirse', () async {
    final bloc = await started();
    live.add(const Err(Failure.server()));
    await pumpEventQueue();
    expect(bloc.state.status, LoadStatus.failure);
    expect(bloc.state.failure, const Failure.server());

    bloc.add(const MovementsRetried());
    await pumpEventQueue();
    expect(bloc.state.status, LoadStatus.loading);
    live.add(livePage(movements(0, 3)));
    await pumpEventQueue();

    expect(bloc.state.status, LoadStatus.success);
    expect(bloc.state.failure, isNull);
    verify(() => repository.watchRecentMovements(uid, 'acc-1')).called(2);
    await bloc.close();
  });
}
