import 'package:bi_app/core/fault_injection/fault_config.dart';
import 'package:bi_app/core/fault_injection/fault_injection_cubit.dart';
import 'package:bi_app/core/fault_injection/fault_panel_access.dart';
import 'package:bi_app/core/fault_injection/presentation/fault_panel_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FaultInjectionCubit cubit;

  setUp(() => cubit = FaultInjectionCubit());
  tearDown(() => cubit.close());

  Future<void> pumpPanel(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: FaultPanelPage(cubit: cubit)));
  }

  Finder modeOf(FaultTarget target, FaultMode mode) => find.descendant(
    of: find.byKey(Key('fault_${target.name}')),
    matching: find.text(FaultPanelPage.modeLabel(mode)),
  );

  testWidgets('lista cada servicio en modo normal', (tester) async {
    await pumpPanel(tester);

    for (final target in FaultTarget.values) {
      expect(find.text(FaultPanelPage.targetLabel(target)), findsOneWidget);
    }
    expect(find.byType(Slider), findsNothing);
  });

  testWidgets('cambiar el modo de un servicio solo afecta a ese', (
    tester,
  ) async {
    await pumpPanel(tester);

    await tester.tap(modeOf(FaultTarget.fx, FaultMode.error));
    await tester.pump();

    expect(cubit.configFor(FaultTarget.fx).mode, FaultMode.error);
    expect(cubit.configFor(FaultTarget.firestore).mode, FaultMode.none);
  });

  testWidgets('latencia muestra el slider y ajusta los milisegundos', (
    tester,
  ) async {
    await pumpPanel(tester);

    await tester.tap(modeOf(FaultTarget.personalization, FaultMode.latency));
    await tester.pump();
    expect(find.text('Latencia: 3.0 s'), findsOneWidget);

    await tester.drag(find.byType(Slider), const Offset(400, 0));
    await tester.pump();

    final config = cubit.configFor(FaultTarget.personalization);
    expect(config.mode, FaultMode.latency);
    expect(config.latencyMs, greaterThan(3000));
  });

  testWidgets('restablecer vuelve todo a normal', (tester) async {
    await cubit.setFault(FaultTarget.fx, FaultMode.offline);
    await pumpPanel(tester);

    await tester.tap(find.byTooltip(FaultPanelPage.reset));
    await tester.pump();

    expect(cubit.configFor(FaultTarget.fx).mode, FaultMode.none);
  });

  test('FaultPanelAccess evalúa la condición en cada consulta', () {
    var allowed = false;
    final access = FaultPanelAccess(() => allowed);

    expect(access.isAllowed, isFalse);
    allowed = true;
    expect(access.isAllowed, isTrue);
  });
}
