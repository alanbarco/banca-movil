import 'dart:async';

import 'package:bi_app/core/flags/flag_keys.dart';
import 'package:bi_app/core/notifications/notifications_toggle.dart';
import 'package:bi_app/core/observability/analytics_events.dart';
import 'package:bi_app/core/routing/pending_route_store.dart';
import 'package:bi_app/core/session/current_user_profile.dart';
import 'package:bi_app/core/storage/local_storage.dart';
import 'package:bi_app/features/notifications/domain/entities/push_message.dart';
import 'package:bi_app/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:bi_app/features/notifications/domain/usecases/resolve_push_route.dart';
import 'package:bi_app/features/notifications/presentation/bloc/notifications_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/fake_observability.dart';
import '../../../personalization/personalization_fixtures.dart';
import '../../notifications_fixtures.dart';

class _MockRepository extends Mock implements NotificationsRepository {}

class _MockToggle extends Mock implements NotificationsToggle {}

const _offer = PushMessage(
  title: 'Oferta',
  body: 'Ahorra para tu viaje',
  type: PushType.offer,
  route: '/offers/student_travel',
);

const _withoutPush = SessionUser(uid: 'uid-ana', segment: 'student');

void main() {
  late _MockRepository repository;
  late _MockToggle toggle;
  late FakeFlags flags;
  late FakeProfile profile;
  late LocalStorage storage;
  late FakeObservabilityService observability;
  late StreamController<PushMessage> foreground;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = await LocalStorage.create();
    repository = _MockRepository();
    toggle = _MockToggle();
    flags = FakeFlags();
    profile = FakeProfile(_withoutPush);
    observability = FakeObservabilityService();
    foreground = StreamController<PushMessage>.broadcast();
    when(
      () => repository.foregroundMessages,
    ).thenAnswer((_) => foreground.stream);
    when(
      () => repository.permission(),
    ).thenAnswer((_) async => PushPermission.notDetermined);
    when(
      () => toggle.setEnabled(enabled: any(named: 'enabled')),
    ).thenAnswer((_) async => true);
  });

  tearDown(() => foreground.close());

  NotificationsCubit build({
    Duration inAppTimeout = NotificationsCubit.defaultInAppTimeout,
  }) => NotificationsCubit(
    repository: repository,
    toggle: toggle,
    resolveRoute: ResolvePushRoute(
      session: FakeSession(),
      pending: PendingRouteStore(),
    ),
    flags: flags,
    currentUser: profile,
    storage: storage,
    observability: observability,
    inAppTimeout: inAppTimeout,
  );

  blocTest<NotificationsCubit, NotificationsState>(
    'primera vez: muestra la explicación antes del permiso',
    build: build,
    act: (cubit) => cubit.start(),
    expect: () => [const NotificationsState(showExplainer: true)],
  );

  blocTest<NotificationsCubit, NotificationsState>(
    'dispositivo nuevo de una cuenta con push activadas: también explica',
    setUp: () => profile.current = ana,
    build: build,
    act: (cubit) => cubit.start(),
    expect: () => [const NotificationsState(showExplainer: true)],
  );

  blocTest<NotificationsCubit, NotificationsState>(
    'aceptar la explicación activa las push y no vuelve a preguntar',
    build: build,
    act: (cubit) async {
      await cubit.start();
      await cubit.acceptExplainer();
      await build().start();
    },
    expect: () => [
      const NotificationsState(showExplainer: true),
      const NotificationsState(),
    ],
    verify: (_) {
      verify(() => toggle.setEnabled(enabled: true)).called(1);
      expect(storage.getBool(NotificationsCubit.explainerShownKey), isTrue);
    },
  );

  blocTest<NotificationsCubit, NotificationsState>(
    'rechazar la explicación se respeta: no pide permiso',
    build: build,
    act: (cubit) async {
      await cubit.start();
      await cubit.declineExplainer();
    },
    skip: 1,
    expect: () => [const NotificationsState()],
    verify: (_) =>
        verifyNever(() => toggle.setEnabled(enabled: any(named: 'enabled'))),
  );

  for (final (description, setup) in <(String, void Function())>[
    (
      'permiso ya concedido',
      () => when(
        () => repository.permission(),
      ).thenAnswer((_) async => PushPermission.granted),
    ),
    (
      'permiso negado en el sistema',
      () => when(
        () => repository.permission(),
      ).thenAnswer((_) async => PushPermission.denied),
    ),
    ('flag apagado', () => flags.turnOff(FlagKeys.pushOptInPrompt)),
  ]) {
    blocTest<NotificationsCubit, NotificationsState>(
      'no explica si: $description',
      setUp: setup,
      build: build,
      act: (cubit) => cubit.start(),
      expect: () => const <NotificationsState>[],
    );
  }

  blocTest<NotificationsCubit, NotificationsState>(
    'push con la app abierta: aviso in-app; "Ver" abre la ruta y registra push_opened',
    setUp: () => when(
      () => repository.permission(),
    ).thenAnswer((_) async => PushPermission.granted),
    build: build,
    act: (cubit) async {
      await cubit.start();
      foreground.add(_offer);
      await pumpEventQueue();
      expect(cubit.open(_offer), '/offers/student_travel');
    },
    expect: () => [
      const NotificationsState(inApp: _offer),
      const NotificationsState(),
    ],
    verify: (_) => expect(
      observability.named(AnalyticsEvents.pushOpened).single.parameters,
      {AnalyticsParams.type: 'offer'},
    ),
  );

  group('el aviso in-app se cierra solo', () {
    const timeout = Duration(milliseconds: 50);
    const movement = PushMessage(
      title: 'Recibiste dinero',
      body: r'+$10,00',
      type: PushType.movement,
      route: '/accounts/acc-1',
    );

    setUp(
      () => when(
        () => repository.permission(),
      ).thenAnswer((_) async => PushPermission.granted),
    );

    test('por defecto dura como máximo 7 segundos', () {
      expect(
        NotificationsCubit.defaultInAppTimeout,
        const Duration(seconds: 7),
      );
    });

    blocTest<NotificationsCubit, NotificationsState>(
      'si nadie lo toca, desaparece al vencer el tiempo',
      build: () => build(inAppTimeout: timeout),
      act: (cubit) async {
        await cubit.start();
        foreground.add(_offer);
      },
      wait: timeout * 2,
      expect: () => [
        const NotificationsState(inApp: _offer),
        const NotificationsState(),
      ],
    );

    blocTest<NotificationsCubit, NotificationsState>(
      'un aviso nuevo reinicia el conteo: el anterior no lo cierra antes',
      build: () => build(inAppTimeout: timeout),
      act: (cubit) async {
        await cubit.start();
        foreground.add(_offer);
        await Future<void>.delayed(timeout * 0.6);
        foreground.add(movement);
        await Future<void>.delayed(timeout * 0.6);
        // El primer temporizador ya habría vencido: el nuevo sigue visible.
        expect(cubit.state.inApp, movement);
      },
      wait: timeout * 2,
      expect: () => [
        const NotificationsState(inApp: _offer),
        const NotificationsState(inApp: movement),
        const NotificationsState(),
      ],
    );

    blocTest<NotificationsCubit, NotificationsState>(
      'cerrarlo a mano cancela el temporizador',
      build: () => build(inAppTimeout: timeout),
      act: (cubit) async {
        await cubit.start();
        foreground.add(_offer);
        await pumpEventQueue();
        cubit.dismiss();
      },
      wait: timeout * 2,
      // Sin un segundo "cerrar" duplicado tras el vencimiento.
      expect: () => [
        const NotificationsState(inApp: _offer),
        const NotificationsState(),
      ],
    );
  });
}
