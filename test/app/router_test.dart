import 'dart:async';

import 'package:bi_app/app/route_guard.dart';
import 'package:bi_app/app/router.dart';
import 'package:bi_app/app/shell/app_shell.dart';
import 'package:bi_app/app/splash_page.dart';
import 'package:bi_app/core/flags/feature_flag_service.dart';
import 'package:bi_app/core/modules/feature_module.dart';
import 'package:bi_app/core/routing/app_routes.dart';
import 'package:bi_app/core/session/session_status.dart';
import 'package:bi_app/core/session/session_timeout_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

class _Session implements SessionStatusSource {
  final _changes = StreamController<SessionStatus>.broadcast();

  @override
  SessionStatus status = SessionStatus.unknown;

  @override
  Stream<SessionStatus> get changes => _changes.stream;

  void set(SessionStatus next) {
    status = next;
    _changes.add(next);
  }
}

class _AllFlagsOn implements FeatureFlagService {
  @override
  bool isEnabled(String key, {String? segment}) => true;

  @override
  Stream<void> get changes => const Stream.empty();
}

/// Feature falsa con las tres pestañas y una ruta pública.
class _FakeModule extends FeatureModule {
  const _FakeModule();

  @override
  void register(GetIt getIt) {}

  @override
  List<RouteBase> get routes => [
    GoRoute(
      path: AppRoutes.login,
      builder: (_, _) => const Scaffold(body: Text('login')),
    ),
  ];

  @override
  List<RouteBase> get shellRoutes => [
    for (final path in [AppRoutes.home, AppRoutes.fx, AppRoutes.profile])
      GoRoute(path: path, builder: (_, _) => Text('page $path')),
  ];
}

void main() {
  late _Session session;
  late SessionTimeoutService timeout;

  setUp(() {
    session = _Session();
    timeout = SessionTimeoutService();
  });

  tearDown(() => timeout.dispose());

  GoRouter build(List<FeatureModule> modules) => createRouter(
    guard: RouteGuard(session: session, flags: _AllFlagsOn()),
    sessionTimeout: timeout,
    modules: modules,
    refreshOn: [session.changes],
  );

  Future<void> pump(WidgetTester tester, GoRouter router) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
  }

  testWidgets('arranca en /splash sin features registradas', (tester) async {
    await pump(tester, build(const []));

    expect(find.byType(SplashPage), findsOneWidget);
    expect(find.text('BI App'), findsOneWidget);
  });

  testWidgets('el cambio de sesión re-evalúa el redirect', (tester) async {
    final router = build(const [_FakeModule()]);
    await pump(tester, router);
    expect(find.byType(SplashPage), findsOneWidget);

    session.set(SessionStatus.unauthenticated);
    await tester.pumpAndSettle();
    expect(find.text('login'), findsOneWidget);

    session.set(SessionStatus.authenticated);
    await tester.pumpAndSettle();
    expect(find.text('page /home'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('el shell navega entre pestañas y reinicia la inactividad', (
    tester,
  ) async {
    session.status = SessionStatus.authenticated;
    final router = build(const [_FakeModule()]);
    await pump(tester, router);
    await tester.pumpAndSettle();
    timeout.start();
    await tester.pump(const Duration(minutes: 4));

    await tester.tap(find.text('Divisas'));
    await tester.pumpAndSettle();

    expect(find.text('page /fx'), findsOneWidget);
    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.selectedIndex, 1);

    // Sin el toque habría vencido a los 5 min; el toque reinició la cuenta.
    await tester.pump(const Duration(minutes: 4));
    expect(timeout.isActive, isTrue);
    timeout.stop();
  });

  testWidgets('logout desde el perfil y nuevo login terminan en /home', (
    tester,
  ) async {
    session.status = SessionStatus.authenticated;
    final router = build(const [_FakeModule()]);
    await pump(tester, router);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();
    expect(find.text('page /profile'), findsOneWidget);

    session.set(SessionStatus.unauthenticated);
    await tester.pumpAndSettle();
    expect(find.text('login'), findsOneWidget);

    session.set(SessionStatus.authenticated);
    await tester.pumpAndSettle();
    expect(find.text('page /home'), findsOneWidget);
    expect(router.routerDelegate.currentConfiguration.uri.path, AppRoutes.home);
  });

  testWidgets('ruta desconocida muestra la página de no encontrada', (
    tester,
  ) async {
    session.status = SessionStatus.authenticated;
    final router = build(const [_FakeModule()]);
    await pump(tester, router);
    await tester.pumpAndSettle();

    router.go('/no-existe');
    await tester.pumpAndSettle();

    expect(find.text('No encontramos esta pantalla.'), findsOneWidget);
  });

  test('destinationsFor solo incluye pestañas registradas', () {
    final destinations = AppShell.destinationsFor([
      GoRoute(path: AppRoutes.home, builder: (_, _) => const SizedBox()),
      GoRoute(path: AppRoutes.profile, builder: (_, _) => const SizedBox()),
    ]);

    expect(destinations.map((d) => d.label), ['Inicio', 'Perfil']);
  });
}
