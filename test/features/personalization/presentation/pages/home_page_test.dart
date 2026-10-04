import 'package:bi_app/core/sdui/home_section.dart';
import 'package:bi_app/core/sdui/home_section_parser.dart';
import 'package:bi_app/core/sdui/section_registry.dart';
import 'package:bi_app/core/ui/widgets/skeleton.dart';
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

import '../../personalization_fixtures.dart';

class _MockHomeCubit extends MockCubit<HomeLayoutState>
    implements HomeLayoutCubit {}

void main() {
  late _MockHomeCubit cubit;
  late SectionRegistry registry;
  late List<String> visited;

  setUp(() {
    cubit = _MockHomeCubit();
    when(() => cubit.refresh()).thenAnswer((_) async {});
    visited = [];
    registry = SectionRegistry()
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
  });

  List<HomeSection> parse(List<Map<String, dynamic>> raw) =>
      const HomeSectionParser().parseSections(raw).sections;

  Future<void> pump(WidgetTester tester, HomeLayoutState state) async {
    when(() => cubit.state).thenReturn(state);
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, _) => BlocProvider<HomeLayoutCubit>.value(
            value: cubit,
            child: HomePage(sections: registry),
          ),
        ),
        GoRoute(
          path: '/offers/:id',
          builder: (_, state) {
            visited.add(state.uri.path);
            return Scaffold(
              appBar: AppBar(),
              body: Text('oferta ${state.pathParameters['id']}'),
            );
          },
        ),
        GoRoute(
          path: '/profile',
          builder: (_, state) {
            visited.add(state.uri.path);
            return const Text('perfil');
          },
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  }

  testWidgets('cargando: skeleton', (tester) async {
    await pump(tester, const HomeLayoutState());

    expect(find.byType(SkeletonList), findsOneWidget);
  });

  testWidgets('dibuja las secciones registradas en el orden recibido', (
    tester,
  ) async {
    await pump(
      tester,
      HomeLayoutState(
        loading: false,
        segment: 'student',
        sections: parse([
          banner('b', 0),
          tip('t', 1),
          offers('o', 2, [offerItem('o1')]),
        ]),
      ),
    );

    expect(find.text('Perfil: Joven / estudiante'), findsOneWidget);
    expect(find.text('Banner b'), findsOneWidget);
    expect(find.text('Consejo t'), findsOneWidget);
    expect(find.text('Oferta o1'), findsOneWidget);
    final bannerY = tester.getTopLeft(find.text('Banner b')).dy;
    final tipY = tester.getTopLeft(find.text('Consejo t')).dy;
    expect(bannerY, lessThan(tipY));
  });

  testWidgets('sección sin widget registrado no rompe la pantalla', (
    tester,
  ) async {
    await pump(
      tester,
      HomeLayoutState(
        loading: false,
        sections: parse([section('c', 'accounts_summary', 0), banner('b', 1)]),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Banner b'), findsOneWidget);
  });

  testWidgets('sin secciones: mensaje vacío', (tester) async {
    await pump(tester, const HomeLayoutState(loading: false));

    expect(
      find.text('Tu inicio no tiene contenido por ahora.'),
      findsOneWidget,
    );
  });

  testWidgets('pull-to-refresh pide la configuración', (tester) async {
    await pump(
      tester,
      HomeLayoutState(loading: false, sections: parse([banner('b', 0)])),
    );

    await tester.fling(find.text('Banner b'), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    verify(() => cubit.refresh()).called(1);
  });

  testWidgets('oferta y acceso rápido navegan a su ruta', (tester) async {
    await pump(
      tester,
      HomeLayoutState(
        loading: false,
        sections: parse([
          quickActions('q', 0),
          offers('o', 1, [offerItem('o1')]),
        ]),
      ),
    );

    await tester.tap(find.text('Oferta o1'));
    await tester.pumpAndSettle();
    expect(visited, ['/offers/o1']);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mi perfil'));
    await tester.pumpAndSettle();
    expect(visited.last, '/profile');
  });

  test('BannerSection.parseColor acepta solo #RRGGBB', () {
    expect(BannerSection.parseColor('#C2410C'), const Color(0xFFC2410C));
    expect(BannerSection.parseColor('rojo'), isNull);
    expect(BannerSection.parseColor(12), isNull);
  });
}
