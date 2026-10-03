import 'package:bi_app/core/data/load_status.dart';
import 'package:bi_app/core/error/failure.dart';
import 'package:bi_app/core/routing/app_routes.dart';
import 'package:bi_app/core/storage/local_storage.dart';
import 'package:bi_app/core/ui/balance_visibility_cubit.dart';
import 'package:bi_app/core/ui/widgets/stale_data_banner.dart';
import 'package:bi_app/features/accounts/domain/entities/account.dart';
import 'package:bi_app/features/accounts/presentation/accounts_texts.dart';
import 'package:bi_app/features/accounts/presentation/bloc/accounts_cubit.dart';
import 'package:bi_app/features/accounts/presentation/widgets/accounts_summary_section.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../accounts_fixtures.dart';

class _MockAccountsCubit extends MockCubit<LoadState<List<Account>>>
    implements AccountsCubit {}

void main() {
  late _MockAccountsCubit cubit;
  late BalanceVisibilityCubit visibility;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    visibility = BalanceVisibilityCubit(await LocalStorage.create());
    cubit = _MockAccountsCubit();
  });

  Future<void> pump(WidgetTester tester, LoadState<List<Account>> state) async {
    when(() => cubit.state).thenReturn(state);
    final router = GoRouter(
      initialLocation: AppRoutes.home,
      routes: [
        GoRoute(
          path: AppRoutes.home,
          builder: (context, _) => Scaffold(
            body: MultiBlocProvider(
              providers: [
                BlocProvider<BalanceVisibilityCubit>.value(value: visibility),
                BlocProvider<AccountsCubit>.value(value: cubit),
              ],
              child: const AccountsSummarySection(),
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.accountDetail,
          builder: (_, state) =>
              Text('detalle ${state.pathParameters['accountId']}'),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  }

  testWidgets('muestra la cuenta y abre su detalle', (tester) async {
    await pump(tester, LoadState.success([savings]));

    expect(find.text('Cuenta de ahorros'), findsOneWidget);
    expect(find.text(r'$1.250,00'), findsOneWidget);
    await tester.tap(find.text('Cuenta de ahorros'));
    await tester.pumpAndSettle();

    expect(find.text('detalle acc-1'), findsOneWidget);
  });

  testWidgets('toggle oculta los saldos', (tester) async {
    await pump(tester, LoadState.success([savings]));

    await tester.tap(find.byTooltip(AccountsTexts.hideBalances));
    await tester.pump();

    expect(find.text(r'$1.250,00'), findsNothing);
    expect(find.text('••••'), findsOneWidget);
    expect(visibility.state, isTrue);
  });

  testWidgets('caché: banner con las cuentas guardadas', (tester) async {
    await pump(tester, LoadState.stale([savings]));

    expect(find.byType(StaleDataBanner), findsOneWidget);
    expect(find.text('Cuenta de ahorros'), findsOneWidget);
  });

  testWidgets('error con reintento', (tester) async {
    await pump(tester, const LoadState.failure(Failure.timeout()));

    await tester.tap(find.text('Reintentar'));

    verify(() => cubit.retry()).called(1);
  });

  testWidgets('sin cuentas: mensaje vacío', (tester) async {
    await pump(tester, const LoadState.empty());

    expect(find.text(AccountsTexts.noAccounts), findsOneWidget);
  });
}
