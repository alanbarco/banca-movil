import 'dart:async';

import 'package:bi_app/core/session/current_user_profile.dart';
import 'package:bi_app/core/session/session_events.dart';
import 'package:bi_app/features/notifications/data/datasources/devices_datasource.dart';
import 'package:bi_app/features/notifications/data/datasources/fcm_datasource.dart';
import 'package:bi_app/features/notifications/data/models/push_message_model.dart';
import 'package:bi_app/features/notifications/data/repositories/notifications_repository_impl.dart';
import 'package:bi_app/features/notifications/domain/entities/push_message.dart';
import 'package:bi_app/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../notifications_fixtures.dart';

class _MockFcm extends Mock implements FcmDatasource {}

class _MockDevices extends Mock implements DevicesDatasource {}

void main() {
  late _MockFcm fcm;
  late _MockDevices devices;
  late SessionEvents events;
  late FakeProfile profile;
  late StreamController<String> tokenRefresh;
  late NotificationsRepositoryImpl repository;

  setUp(() {
    fcm = _MockFcm();
    devices = _MockDevices();
    events = SessionEvents();
    profile = FakeProfile(ana);
    tokenRefresh = StreamController<String>.broadcast();

    when(() => fcm.tokenRefresh).thenAnswer((_) => tokenRefresh.stream);
    when(
      () => fcm.permission(),
    ).thenAnswer((_) async => PushPermission.granted);
    when(() => fcm.token()).thenAnswer((_) async => 'token-1');
    when(() => fcm.subscribe(any())).thenAnswer((_) async {});
    when(() => fcm.unsubscribe(any())).thenAnswer((_) async {});
    when(() => fcm.deleteToken()).thenAnswer((_) async {});
    when(() => devices.save(any(), any())).thenAnswer((_) async {});
    when(() => devices.delete(any(), any())).thenAnswer((_) async {});
    when(
      () => devices.setPreference(any(), enabled: any(named: 'enabled')),
    ).thenAnswer((_) async {});

    repository = NotificationsRepositoryImpl(
      fcm: fcm,
      devices: devices,
      sessionEvents: events,
      currentUser: profile,
    );
  });

  tearDown(() async {
    await repository.dispose();
    await tokenRefresh.close();
  });

  Future<void> signIn() async {
    events.publish(const SignedIn(uid: 'uid-ana', segment: 'student'));
    await pumpEventQueue();
  }

  test('al iniciar sesión guarda el token y suscribe all + segmento', () async {
    await signIn();

    verify(() => devices.save('uid-ana', 'token-1')).called(1);
    verify(() => fcm.subscribe('all')).called(1);
    verify(() => fcm.subscribe('segment_student')).called(1);
  });

  test('sin push activadas en el perfil no registra nada', () async {
    profile.current = const SessionUser(uid: 'uid-ana', segment: 'student');
    await signIn();

    verifyNever(() => fcm.token());
    verifyNever(() => fcm.subscribe(any()));
  });

  test('sin permiso del sistema no registra nada', () async {
    when(() => fcm.permission()).thenAnswer((_) async => PushPermission.denied);
    await signIn();

    verifyNever(() => devices.save(any(), any()));
  });

  test('cambio de segmento cambia de topic', () async {
    await signIn();
    events.publish(
      const SegmentChanged(oldSegment: 'student', newSegment: 'professional'),
    );
    await pumpEventQueue();

    verify(() => fcm.unsubscribe('segment_student')).called(1);
    verify(() => fcm.subscribe('segment_professional')).called(1);
  });

  test('al cerrar sesión da de baja topics, token y dispositivo', () async {
    await signIn();

    await events.signingOut('uid-ana');

    verify(() => fcm.unsubscribe('all')).called(1);
    verify(() => fcm.unsubscribe('segment_student')).called(1);
    verify(() => devices.delete('uid-ana', 'token-1')).called(1);
    verify(() => fcm.deleteToken()).called(1);
  });

  test('token renovado se guarda para el cliente registrado', () async {
    await signIn();
    tokenRefresh.add('token-2');
    await pumpEventQueue();

    verify(() => devices.save('uid-ana', 'token-2')).called(1);
  });

  test('desactivar guarda la preferencia y da de baja', () async {
    await signIn();

    await repository.setEnabled(enabled: false);

    verify(() => devices.setPreference('uid-ana', enabled: false)).called(1);
    verify(() => fcm.deleteToken()).called(1);
  });

  test('un fallo de FCM no rompe la sesión', () async {
    when(() => fcm.token()).thenThrow(StateError('sin Play Services'));

    await expectLater(signIn(), completes);
    verifyNever(() => fcm.subscribe(any()));
  });

  test('el payload se traduce a PushMessage', () {
    expect(
      PushMessageModel.fromParts(
        title: 'Nuevo movimiento',
        body: 'Recibiste \$40.00',
        data: {'type': 'movement', 'route': '/accounts/acc-1'},
      ),
      const PushMessage(
        title: 'Nuevo movimiento',
        body: 'Recibiste \$40.00',
        type: PushType.movement,
        route: '/accounts/acc-1',
      ),
    );
    expect(
      PushMessageModel.fromParts(title: null, body: null, data: {}),
      const PushMessage(title: '', body: ''),
    );
  });
}
