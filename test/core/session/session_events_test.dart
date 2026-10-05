import 'dart:async';

import 'package:bi_app/core/session/session_events.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late SessionEvents events;

  setUp(() => events = SessionEvents());

  test('signingOut publica SigningOut y espera las limpiezas', () async {
    final published = <SessionEvent>[];
    events.stream.listen(published.add);
    final cleaned = <String>[];
    events.addSignOutCleanup((uid) async {
      await Future<void>.delayed(Duration.zero);
      cleaned.add(uid);
    });

    await events.signingOut('uid-ana');

    expect(published, [const SigningOut(uid: 'uid-ana')]);
    expect(cleaned, ['uid-ana']);
  });

  test('una limpieza que falla no impide cerrar sesión', () async {
    events
      ..addSignOutCleanup((_) async => throw StateError('sin red'))
      ..addSignOutCleanup((_) => throw StateError('síncrono'));

    await expectLater(events.signingOut('uid-ana'), completes);
  });

  test('sin red, no espera más que el timeout', () async {
    events.addSignOutCleanup((_) => Completer<void>().future);

    await expectLater(
      events.signingOut('uid-ana', timeout: const Duration(milliseconds: 10)),
      completes,
    );
  });
}
