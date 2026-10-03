import 'package:bi_app/core/routing/app_routes.dart';
import 'package:bi_app/core/routing/pending_route_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppRoutes.isKnown', () {
    test('acepta rutas fijas y con parámetros, con query o barra final', () {
      for (final route in [
        '/home',
        '/fx',
        '/profile/',
        '/accounts/abc123',
        '/offers/student_savings?src=push',
        '/debug/faults',
      ]) {
        expect(AppRoutes.isKnown(route), isTrue, reason: route);
      }
    });

    test('rechaza rutas desconocidas, externas o incompletas', () {
      for (final route in [
        '',
        'home',
        '/accounts',
        '/accounts/',
        '/accounts/a/b',
        '/admin',
        'https://evil.test/home',
        '//evil.test/home',
      ]) {
        expect(AppRoutes.isKnown(route), isFalse, reason: route);
      }
    });

    test('helpers construyen rutas válidas', () {
      expect(AppRoutes.account('a b'), '/accounts/a%20b');
      expect(AppRoutes.isKnown(AppRoutes.offer('o1')), isTrue);
    });

    test('isPublic distingue rutas sin sesión', () {
      expect(AppRoutes.isPublic('/login'), isTrue);
      expect(AppRoutes.isPublic('/home'), isFalse);
    });
  });

  group('PendingRouteStore', () {
    test('guarda rutas protegidas conocidas y take las consume', () {
      final store = PendingRouteStore()..save('/accounts/a1');

      expect(store.pending, '/accounts/a1');
      expect(store.take(), '/accounts/a1');
      expect(store.take(), isNull);
    });

    test('ignora rutas desconocidas o públicas', () {
      final store = PendingRouteStore()
        ..save('/hack')
        ..save('/login');

      expect(store.pending, isNull);
    });
  });
}
