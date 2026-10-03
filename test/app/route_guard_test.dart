import 'package:bi_app/app/route_guard.dart';
import 'package:bi_app/core/flags/feature_flag_service.dart';
import 'package:bi_app/core/flags/flag_keys.dart';
import 'package:bi_app/core/routing/pending_route_store.dart';
import 'package:bi_app/core/session/session_status.dart';
import 'package:flutter_test/flutter_test.dart';

class _Session implements SessionStatusSource {
  @override
  SessionStatus status = SessionStatus.unknown;

  @override
  Stream<SessionStatus> get changes => const Stream.empty();
}

class _Flags implements FeatureFlagService {
  final enabled = <String>{FlagKeys.fxService, FlagKeys.offers};
  final segmentsSeen = <String?>[];

  @override
  bool isEnabled(String key, {String? segment}) {
    segmentsSeen.add(segment);
    return enabled.contains(key);
  }

  @override
  Stream<void> get changes => const Stream.empty();
}

void main() {
  late _Session session;
  late _Flags flags;
  late PendingRouteStore pending;
  late RouteGuard guard;

  RouteGuard buildGuard({bool demoTools = false}) => RouteGuard(
    session: session,
    flags: flags,
    pendingRoutes: pending,
    currentSegment: () => 'student',
    demoTools: demoTools,
  );

  String? go(String location) => guard.redirect(Uri.parse(location));

  setUp(() {
    session = _Session();
    flags = _Flags();
    pending = PendingRouteStore();
    guard = buildGuard();
  });

  group('sesión desconocida (arranque)', () {
    test('permanece en /splash', () {
      expect(go('/splash'), isNull);
    });

    test('cualquier otra ruta va a /splash y guarda el destino', () {
      expect(go('/accounts/a1'), '/splash');
      expect(pending.pending, '/accounts/a1');
    });
  });

  group('no autenticado', () {
    setUp(() => session.status = SessionStatus.unauthenticated);

    test('rutas públicas se permiten', () {
      expect(go('/login'), isNull);
      expect(go('/register'), isNull);
      expect(go('/forgot-password'), isNull);
    });

    test('splash y rutas protegidas van a /login guardando el destino', () {
      expect(go('/splash'), '/login');
      expect(go('/offers/o1?src=push'), '/login');
      expect(pending.pending, '/offers/o1?src=push');
    });
  });

  test('sin perfil siempre va a /register', () {
    session.status = SessionStatus.needsOnboarding;

    expect(go('/home'), '/register');
    expect(go('/login'), '/register');
    expect(go('/register'), isNull);
  });

  group('autenticado', () {
    setUp(() => session.status = SessionStatus.authenticated);

    test('rutas públicas van a /home', () {
      expect(go('/splash'), '/home');
      expect(go('/login'), '/home');
    });

    test('rutas públicas van a la ruta pendiente y la consumen', () {
      pending.save('/accounts/a1');

      expect(go('/login'), '/accounts/a1');
      expect(go('/login'), '/home');
    });

    test('rutas protegidas sin flag se permiten', () {
      expect(go('/home'), isNull);
      expect(go('/accounts/a1'), isNull);
      expect(go('/profile'), isNull);
    });

    test('ruta con flag apagado va a /home', () {
      expect(go('/fx'), isNull);
      expect(go('/offers/o1'), isNull);

      flags.enabled.clear();

      expect(go('/fx'), '/home');
      expect(go('/offers/o1'), '/home');
    });

    test('los flags se evalúan con el segmento del cliente', () {
      go('/fx');

      expect(flags.segmentsSeen, ['student']);
    });

    test('/debug/faults exige DEMO_TOOLS y el flag', () {
      flags.enabled.add(FlagKeys.demoFaultPanel);
      expect(go('/debug/faults'), '/home');

      guard = buildGuard(demoTools: true);
      expect(go('/debug/faults'), isNull);

      flags.enabled.remove(FlagKeys.demoFaultPanel);
      expect(go('/debug/faults'), '/home');
    });
  });
}
