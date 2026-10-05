import 'package:bi_app/core/routing/pending_route_store.dart';
import 'package:bi_app/core/session/session_status.dart';
import 'package:bi_app/features/notifications/domain/usecases/resolve_push_route.dart';
import 'package:flutter_test/flutter_test.dart';

import '../notifications_fixtures.dart';

void main() {
  late FakeSession session;
  late PendingRouteStore pending;
  late ResolvePushRoute resolve;

  setUp(() {
    session = FakeSession();
    pending = PendingRouteStore();
    resolve = ResolvePushRoute(session: session, pending: pending);
  });

  test('con sesión, una ruta conocida se abre tal cual', () {
    expect(resolve('/accounts/acc-1'), '/accounts/acc-1');
    expect(resolve('/offers/student_savings'), '/offers/student_savings');
    expect(pending.pending, isNull);
  });

  test('ruta desconocida, externa o ausente abre el inicio', () {
    expect(resolve('/no-existe'), '/home');
    expect(resolve('https://phishing.example/login'), '/home');
    expect(resolve(null), '/home');
  });

  test('sin sesión guarda la ruta para después del login', () {
    session.status = SessionStatus.unauthenticated;

    expect(resolve('/accounts/acc-1'), isNull);
    expect(pending.take(), '/accounts/acc-1');
  });

  test('al arrancar (sesión desconocida) también queda pendiente', () {
    session.status = SessionStatus.unknown;

    expect(resolve('/offers/pro_travel'), isNull);
    expect(pending.pending, '/offers/pro_travel');
  });
}
