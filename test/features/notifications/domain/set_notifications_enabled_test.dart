import 'package:bi_app/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:bi_app/features/notifications/domain/usecases/set_notifications_enabled.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepository extends Mock implements NotificationsRepository {}

void main() {
  late _MockRepository repository;
  late SetNotificationsEnabled toggle;

  setUp(() {
    repository = _MockRepository();
    toggle = SetNotificationsEnabled(repository);
    when(
      () => repository.setEnabled(enabled: any(named: 'enabled')),
    ).thenAnswer((_) async {});
  });

  test('activar sin decisión previa pide el permiso del sistema', () async {
    when(
      () => repository.permission(),
    ).thenAnswer((_) async => PushPermission.notDetermined);
    when(
      () => repository.requestPermission(),
    ).thenAnswer((_) async => PushPermission.granted);

    expect(await toggle.setEnabled(enabled: true), isTrue);
    verify(() => repository.setEnabled(enabled: true)).called(1);
  });

  test('si niega el permiso no se activa nada', () async {
    when(
      () => repository.permission(),
    ).thenAnswer((_) async => PushPermission.notDetermined);
    when(
      () => repository.requestPermission(),
    ).thenAnswer((_) async => PushPermission.denied);

    expect(await toggle.setEnabled(enabled: true), isFalse);
    verifyNever(() => repository.setEnabled(enabled: any(named: 'enabled')));
  });

  test('con permiso ya negado no vuelve a pedirlo', () async {
    when(
      () => repository.permission(),
    ).thenAnswer((_) async => PushPermission.denied);

    expect(await toggle.setEnabled(enabled: true), isFalse);
    verifyNever(() => repository.requestPermission());
  });

  test('desactivar no necesita permiso', () async {
    expect(await toggle.setEnabled(enabled: false), isTrue);
    verify(() => repository.setEnabled(enabled: false)).called(1);
    verifyNever(() => repository.permission());
  });
}
