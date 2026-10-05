import 'package:bi_app/core/data/data_snapshot.dart';
import 'package:bi_app/core/data/load_status.dart';
import 'package:bi_app/core/error/result.dart';
import 'package:bi_app/core/sdui/home_section.dart';
import 'package:bi_app/core/sdui/home_section_parser.dart';
import 'package:bi_app/core/sdui/section_registry.dart';
import 'package:bi_app/core/storage/local_storage.dart';
import 'package:bi_app/core/ui/balance_visibility_cubit.dart';
import 'package:bi_app/core/ui/theme.dart';
import 'package:bi_app/features/accounts/domain/entities/account.dart';
import 'package:bi_app/features/accounts/presentation/accounts_texts.dart';
import 'package:bi_app/features/accounts/presentation/bloc/account_detail_cubit.dart';
import 'package:bi_app/features/accounts/presentation/bloc/accounts_cubit.dart';
import 'package:bi_app/features/accounts/presentation/bloc/movements_bloc.dart';
import 'package:bi_app/features/accounts/presentation/pages/account_detail_page.dart';
import 'package:bi_app/features/accounts/presentation/widgets/accounts_summary_section.dart';
import 'package:bi_app/features/fx/domain/repositories/fx_repository.dart';
import 'package:bi_app/features/fx/presentation/bloc/fx_cubit.dart';
import 'package:bi_app/features/fx/presentation/pages/fx_page.dart';
import 'package:bi_app/features/personalization/presentation/bloc/home_layout_cubit.dart';
import 'package:bi_app/features/personalization/presentation/pages/home_page.dart';
import 'package:bi_app/features/personalization/presentation/widgets/banner_section.dart';
import 'package:bi_app/features/personalization/presentation/widgets/offer_carousel_section.dart';
import 'package:bi_app/features/personalization/presentation/widgets/quick_actions_section.dart';
import 'package:bi_app/features/personalization/presentation/widgets/tip_section.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/accounts/accounts_fixtures.dart';
import '../features/fx/fx_fixtures.dart';
import '../features/personalization/personalization_fixtures.dart';

class _MockHomeCubit extends MockCubit<HomeLayoutState>
    implements HomeLayoutCubit {}

class _MockAccountsCubit extends MockCubit<LoadState<List<Account>>>
    implements AccountsCubit {}

class _MockDetailCubit extends MockCubit<LoadState<Account>>
    implements AccountDetailCubit {}

class _MockMovementsBloc extends MockBloc<MovementsEvent, MovementsState>
    implements MovementsBloc {}

class _MockFxRepository extends Mock implements FxRepository {}

/// Teléfono pequeño (360 dp de ancho) con el texto al 200 % (FR-033).
void main() {
  late BalanceVisibilityCubit visibility;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    visibility = BalanceVisibilityCubit(await LocalStorage.create());
  });

  Future<void> pumpScaled(WidgetTester tester, Widget app) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      BlocProvider<BalanceVisibilityCubit>.value(value: visibility, child: app),
    );
    await tester.pumpAndSettle();
  }

  Future<void> checkGuidelines(WidgetTester tester) async {
    // Un overflow se reporta como excepción del framework.
    expect(tester.takeException(), isNull);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
  }

  /// Recorre la pantalla de arriba abajo y revisa cada tramo: lo que no se
  /// ve ni siquiera se construye.
  Future<void> expectAccessible(WidgetTester tester) async {
    final context = tester.element(find.byType(Scaffold).first);
    expect(MediaQuery.textScalerOf(context).scale(10), 20);
    await checkGuidelines(tester);

    final vertical = find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down,
    );
    final position = tester.state<ScrollableState>(vertical.first).position;
    while (position.pixels < position.maxScrollExtent) {
      await tester.drag(
        vertical.first,
        Offset(0, -position.viewportDimension / 2),
      );
      await tester.pumpAndSettle();
      await checkGuidelines(tester);
    }
  }

  for (final (name, theme) in [
    ('tema claro', AppTheme.light()),
    ('tema oscuro', AppTheme.dark()),
  ]) {
    group(name, () {
      testWidgets('inicio', (tester) async {
        final semantics = tester.ensureSemantics();
        final home = _MockHomeCubit();
        final accounts = _MockAccountsCubit();
        when(() => accounts.state).thenReturn(LoadState.success([savings]));
        when(() => home.state).thenReturn(
          HomeLayoutState(
            loading: false,
            segment: 'professional',
            sections: const HomeSectionParser().parseSections([
              quickActions('q', 0),
              section('a', 'accounts_summary', 1),
              banner('b', 2),
              offers('o', 3, [offerItem('o1')]),
              tip('t', 4),
            ]).sections,
          ),
        );
        final registry = SectionRegistry()
          ..register(
            HomeSectionType.accountsSummary,
            (_, _) => BlocProvider<AccountsCubit>.value(
              value: accounts,
              child: const AccountsSummarySection(),
            ),
          )
          ..register(
            HomeSectionType.banner,
            (_, section) => BannerSection(section: section),
          )
          ..register(
            HomeSectionType.offerCarousel,
            (_, section) => OfferCarouselSection(section: section),
          )
          ..register(
            HomeSectionType.quickActions,
            (_, section) => QuickActionsSection(section: section),
          )
          ..register(
            HomeSectionType.tip,
            (_, section) => TipSection(section: section),
          );

        await pumpScaled(
          tester,
          MaterialApp.router(
            theme: theme,
            routerConfig: GoRouter(
              initialLocation: '/home',
              routes: [
                GoRoute(
                  path: '/home',
                  builder: (_, _) => BlocProvider<HomeLayoutCubit>.value(
                    value: home,
                    child: HomePage(sections: registry),
                  ),
                ),
              ],
            ),
          ),
        );

        expect(find.text('Mi perfil'), findsOneWidget);
        expect(find.text('Cuenta de ahorros'), findsOneWidget);
        await expectAccessible(tester);
        expect(find.text('Consejo t'), findsOneWidget);
        semantics.dispose();
      });

      testWidgets('detalle de cuenta', (tester) async {
        final semantics = tester.ensureSemantics();
        final detail = _MockDetailCubit();
        final movementsBloc = _MockMovementsBloc();
        when(() => detail.state).thenReturn(LoadState.success(savings));
        when(() => movementsBloc.state).thenReturn(
          MovementsState(
            status: LoadStatus.success,
            live: movements(0, 5),
            liveHasMore: true,
          ),
        );

        await pumpScaled(
          tester,
          MaterialApp(
            theme: theme,
            home: MultiBlocProvider(
              providers: [
                BlocProvider<AccountDetailCubit>.value(value: detail),
                BlocProvider<MovementsBloc>.value(value: movementsBloc),
              ],
              child: const AccountDetailPage(),
            ),
          ),
        );

        expect(find.text(r'$1.250,00'), findsOneWidget);
        await expectAccessible(tester);
        expect(find.text(AccountsTexts.loadMore), findsOneWidget);
        semantics.dispose();
      });

      testWidgets('divisas', (tester) async {
        final semantics = tester.ensureSemantics();
        final repository = _MockFxRepository();
        when(() => repository.latest()).thenAnswer(
          (_) async =>
              Success(DataSnapshot(data: rates, lastSyncedAt: fetchedAt)),
        );

        await pumpScaled(
          tester,
          MaterialApp(
            theme: theme,
            home: BlocProvider(
              create: (_) => FxCubit(repository: repository)..load(),
              child: const FxPage(),
            ),
          ),
        );

        expect(find.byKey(const Key('fx_amount')), findsOneWidget);
        await expectAccessible(tester);
        expect(find.text('0,9200'), findsOneWidget);
        semantics.dispose();
      });
    });
  }
}
