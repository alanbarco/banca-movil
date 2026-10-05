import 'package:bi_app/core/ui/widgets/money_text.dart';
import 'package:bi_app/features/accounts/presentation/widgets/account_card.dart';
import 'package:bi_app/features/accounts/presentation/widgets/movement_tile.dart';
import 'package:bi_app/features/notifications/presentation/widgets/permission_explainer_dialog.dart';
import 'package:bi_app/main.dart' as app;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Flujo crítico contra el proyecto Firebase real (SC-012, quickstart V19).
///
/// `flutter test integration_test --dart-define-from-file=.env`
///
/// Cada ejecución deja un usuario `e2e+<timestamp>@example.com` en el
/// proyecto de desarrollo (riesgo documentado en research R10).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'registro → cuenta con saldo en inicio → detalle con movimientos',
    (tester) async {
      await app.main();
      // Una sesión previa en el dispositivo llevaría directo al inicio.
      await FirebaseAuth.instance.signOut();

      await _pumpUntilFound(tester, find.text('Hazte cliente'));
      await tester.tap(find.text('Hazte cliente'));
      await _pumpUntilFound(tester, find.text('Crea tu acceso'));

      final email = 'e2e+${DateTime.now().millisecondsSinceEpoch}@example.com';
      await tester.enterText(_field('Nombre completo'), 'Cliente E2E');
      await tester.enterText(_field('Correo electrónico'), email);
      await tester.enterText(_field('Contraseña'), 'Prueba2026');
      await _tapAndWait(tester, 'Continuar', next: '¿Qué te describe mejor?');

      await tester.tap(find.text('Profesional'));
      await _tapAndWait(tester, 'Continuar', next: '¿Qué te interesa?');

      await tester.tap(find.text('Ahorro'));
      await _tapAndWait(tester, 'Continuar', next: 'Términos y condiciones');

      await tester.tap(find.text('Acepto los términos y condiciones'));
      await tester.pump();
      await tester.tap(find.text('Abrir mi cuenta'));

      // Inicio: la cuenta abierta en el onboarding, con su saldo.
      await _pumpUntilFound(
        tester,
        find.byType(AccountCard),
        timeout: const Duration(seconds: 45),
      );
      expect(find.text('Cuenta de ahorros'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AccountCard),
          matching: find.byType(MoneyText),
        ),
        findsOneWidget,
      );

      // La explicación del permiso de push sale una vez por dispositivo.
      await _dismissIfShown(
        tester,
        find.text(PermissionExplainerDialog.decline),
      );

      // Detalle: al menos 3 movimientos de la semilla de onboarding.
      await tester.tap(find.byType(AccountCard));
      await _pumpUntilFound(tester, find.byType(MovementTile));
      expect(find.byType(MovementTile), findsAtLeastNWidgets(3));
    },
  );
}

Future<void> _dismissIfShown(WidgetTester tester, Finder finder) async {
  final end = DateTime.now().add(const Duration(seconds: 3));
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isNotEmpty) {
      await tester.tap(finder);
      await tester.pump(const Duration(milliseconds: 300));
      return;
    }
  }
}

Finder _field(String label) => find.widgetWithText(TextField, label);

Future<void> _tapAndWait(
  WidgetTester tester,
  String button, {
  required String next,
}) async {
  await tester.tap(find.text(button));
  await _pumpUntilFound(tester, find.text(next));
}

/// `pumpAndSettle` no termina con indicadores de progreso en pantalla.
Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('No apareció $finder en ${timeout.inSeconds} s');
}
