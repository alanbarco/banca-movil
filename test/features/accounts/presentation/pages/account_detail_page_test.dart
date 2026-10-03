import 'package:bi_app/core/data/load_status.dart';
import 'package:bi_app/core/error/failure.dart';
import 'package:bi_app/core/storage/local_storage.dart';
import 'package:bi_app/core/ui/balance_visibility_cubit.dart';
import 'package:bi_app/core/ui/widgets/skeleton.dart';
import 'package:bi_app/core/ui/widgets/stale_data_banner.dart';
import 'package:bi_app/features/accounts/domain/entities/account.dart';
import 'package:bi_app/features/accounts/domain/entities/movement.dart';
import 'package:bi_app/features/accounts/presentation/accounts_texts.dart';
import 'package:bi_app/features/accounts/presentation/bloc/account_detail_cubit.dart';
import 'package:bi_app/features/accounts/presentation/bloc/movements_bloc.dart';
import 'package:bi_app/features/accounts/presentation/pages/account_detail_page.dart';
import 'package:bi_app/features/accounts/presentation/widgets/movement_tile.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../accounts_fixtures.dart';

class _MockDetailCubit extends MockCubit<LoadState<Account>>
    implements AccountDetailCubit {}

class _MockMovementsBloc extends MockBloc<MovementsEvent, MovementsState>
    implements MovementsBloc {}

void main() {
  late _MockDetailCubit detail;
  late _MockMovementsBloc movementsBloc;
  late BalanceVisibilityCubit visibility;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    visibility = BalanceVisibilityCubit(await LocalStorage.create());
    detail = _MockDetailCubit();
    movementsBloc = _MockMovementsBloc();
  });

  Future<void> pump(
    WidgetTester tester, {
    LoadState<Account>? account,
    MovementsState movements = const MovementsState(status: LoadStatus.loading),
  }) async {
    when(() => detail.state).thenReturn(account ?? LoadState.success(savings));
    when(() => movementsBloc.state).thenReturn(movements);
    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider<BalanceVisibilityCubit>.value(value: visibility),
            BlocProvider<AccountDetailCubit>.value(value: detail),
            BlocProvider<MovementsBloc>.value(value: movementsBloc),
          ],
          child: const AccountDetailPage(),
        ),
      ),
    );
  }

  MovementsState loaded(
    List<Movement> items, {
    LoadStatus status = LoadStatus.success,
    bool hasMore = false,
    Failure? loadMoreFailure,
    DateTime? lastSyncedAt,
  }) => MovementsState(
    status: status,
    live: items,
    liveHasMore: hasMore,
    loadMoreFailure: loadMoreFailure,
    lastSyncedAt: lastSyncedAt,
  );

  testWidgets('cargando: skeletons para saldo y movimientos', (tester) async {
    await pump(tester, account: const LoadState.loading());

    expect(find.byType(Skeleton), findsWidgets);
    expect(find.byType(SkeletonList), findsOneWidget);
    expect(find.byType(MovementTile), findsNothing);
  });

  testWidgets('lista: saldo, número enmascarado y movimientos', (tester) async {
    await pump(
      tester,
      movements: loaded([
        movement(1, amountCents: 2500),
        movement(2, type: MovementType.debit, amountCents: 1000),
      ]),
    );

    expect(find.text('Cuenta de ahorros'), findsOneWidget);
    expect(find.text('•••• 7890'), findsOneWidget);
    expect(find.text(r'$1.250,00'), findsOneWidget);
    expect(find.byType(MovementTile), findsNWidgets(2));
    expect(find.text(r'+$25,00'), findsOneWidget);
    expect(find.text(r'−$10,00'), findsOneWidget);
    expect(find.textContaining('Ingreso ·'), findsOneWidget);
    expect(find.textContaining('Egreso ·'), findsOneWidget);
    expect(find.text(AccountsTexts.endOfList), findsOneWidget);
  });

  testWidgets('vacío: mensaje sin movimientos', (tester) async {
    await pump(
      tester,
      movements: const MovementsState(status: LoadStatus.empty),
    );

    expect(find.text(AccountsTexts.noMovements), findsOneWidget);
  });

  testWidgets('error de movimientos con reintento', (tester) async {
    await pump(
      tester,
      movements: const MovementsState(
        status: LoadStatus.failure,
        failure: Failure.network(),
      ),
    );

    expect(
      find.text(AccountsTexts.loadError(const Failure.network())),
      findsOneWidget,
    );
    await tester.tap(find.text('Reintentar'));

    verify(() => movementsBloc.add(const MovementsRetried())).called(1);
  });

  testWidgets('cuenta inexistente: mensaje sin reintento', (tester) async {
    await pump(tester, account: const LoadState.failure(Failure.notFound()));

    expect(find.text('No encontramos esta cuenta.'), findsOneWidget);
    expect(find.text('Reintentar'), findsNothing);
  });

  testWidgets('datos de caché: banner de datos desactualizados', (
    tester,
  ) async {
    final synced = DateTime(2026, 10, 3, 9, 5);
    await pump(
      tester,
      movements: loaded(
        [movement(1)],
        status: LoadStatus.stale,
        lastSyncedAt: synced,
      ),
    );

    expect(find.byType(StaleDataBanner), findsOneWidget);
    expect(find.text('Sin conexión · actualizado a las 09:05'), findsOneWidget);
  });

  testWidgets('saldos ocultos: montos enmascarados y alternables', (
    tester,
  ) async {
    await visibility.setHidden(hidden: true);
    await pump(tester, movements: loaded([movement(1, amountCents: 2500)]));

    expect(find.text(r'$1.250,00'), findsNothing);
    expect(find.text(r'+$25,00'), findsNothing);
    expect(find.text('••••'), findsNWidgets(2));

    await tester.tap(find.byTooltip(AccountsTexts.showBalances));
    await tester.pump();

    expect(find.text(r'$1.250,00'), findsOneWidget);
    expect(visibility.state, isFalse);
  });

  testWidgets('"Ver más" pide la página siguiente', (tester) async {
    await pump(tester, movements: loaded(movements(0, 3), hasMore: true));

    await tester.tap(find.text(AccountsTexts.loadMore));

    verify(
      () => movementsBloc.add(const MovementsLoadMoreRequested()),
    ).called(1);
  });

  testWidgets('error al pedir más: aviso con reintento', (tester) async {
    await pump(
      tester,
      movements: loaded(
        movements(0, 3),
        hasMore: true,
        loadMoreFailure: const Failure.network(),
      ),
    );

    expect(find.text(AccountsTexts.loadMoreFailed), findsOneWidget);
    await tester.tap(find.text('Reintentar'));

    verify(
      () => movementsBloc.add(const MovementsLoadMoreRequested()),
    ).called(1);
  });
}
