import 'dart:async';

import 'package:bi_app/features/notifications/domain/entities/push_message.dart';
import 'package:bi_app/features/notifications/presentation/bloc/notifications_cubit.dart';
import 'package:bi_app/features/notifications/presentation/widgets/in_app_notification_listener.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCubit extends MockCubit<NotificationsState>
    implements NotificationsCubit {}

const _offer = PushMessage(
  title: 'Viaja sin preocupaciones',
  body: 'Consulta el tipo de cambio',
  type: PushType.offer,
  route: '/offers/pro_travel',
);

void main() {
  late _MockCubit cubit;
  late StreamController<NotificationsState> states;

  setUp(() {
    cubit = _MockCubit();
    states = StreamController<NotificationsState>();
    whenListen(cubit, states.stream, initialState: const NotificationsState());
  });

  tearDown(() => states.close());

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      home: BlocProvider<NotificationsCubit>.value(
        value: cubit,
        child: const InAppNotificationListener(
          child: Scaffold(body: Center(child: Text('Contenido'))),
        ),
      ),
    ),
  );

  Future<void> receive(WidgetTester tester) async {
    states.add(const NotificationsState(inApp: _offer));
    await tester.pumpAndSettle();
  }

  testWidgets('la push aparece arriba, encima del contenido sin moverlo', (
    tester,
  ) async {
    await pump(tester);
    final before = tester.getTopLeft(find.text('Contenido'));

    await receive(tester);

    expect(find.text(_offer.title), findsOneWidget);
    expect(find.text(InAppNotificationListener.view), findsOneWidget);
    final screenHeight =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(
      tester.getTopLeft(find.text(_offer.title)).dy,
      lessThan(screenHeight / 4),
    );
    expect(tester.getTopLeft(find.text('Contenido')), before);
  });

  testWidgets('la ✕ avisa al cubit', (tester) async {
    await pump(tester);
    await receive(tester);

    await tester.tap(find.byTooltip(InAppNotificationListener.close));

    verify(() => cubit.dismiss()).called(1);
  });

  testWidgets('deslizarla hacia arriba también la cierra', (tester) async {
    await pump(tester);
    await receive(tester);

    await tester.fling(find.text(_offer.title), const Offset(0, -300), 1000);
    await tester.pumpAndSettle();

    verify(() => cubit.dismiss()).called(1);
  });

  testWidgets('cuando el cubit la cierra (7 s), desaparece', (tester) async {
    await pump(tester);
    await receive(tester);

    states.add(const NotificationsState());
    await tester.pumpAndSettle();

    expect(find.text(_offer.title), findsNothing);
  });
}
