import 'package:bi_app/core/session/session_timeout_service.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('vence a los 5 minutos sin interacción', () {
    fakeAsync((async) {
      final service = SessionTimeoutService();
      var timeouts = 0;
      service.timeouts.listen((_) => timeouts++);

      service.start();
      async.elapse(const Duration(minutes: 4, seconds: 59));
      expect(timeouts, 0);

      async.elapse(const Duration(seconds: 1));
      expect(timeouts, 1);
      expect(service.isActive, isFalse);
    });
  });

  test('registerInteraction reinicia la cuenta', () {
    fakeAsync((async) {
      final service = SessionTimeoutService();
      var timeouts = 0;
      service.timeouts.listen((_) => timeouts++);

      service.start();
      async.elapse(const Duration(minutes: 4));
      service.registerInteraction();
      async.elapse(const Duration(minutes: 4));
      expect(timeouts, 0);

      async.elapse(const Duration(minutes: 1));
      expect(timeouts, 1);
    });
  });

  test('sin start las interacciones no inician la cuenta', () {
    fakeAsync((async) {
      final service = SessionTimeoutService();
      var timeouts = 0;
      service.timeouts.listen((_) => timeouts++);

      service.registerInteraction();
      async.elapse(const Duration(minutes: 10));

      expect(timeouts, 0);
      expect(service.isActive, isFalse);
    });
  });

  test('stop cancela la cuenta (cierre de sesión manual)', () {
    fakeAsync((async) {
      final service = SessionTimeoutService();
      var timeouts = 0;
      service.timeouts.listen((_) => timeouts++);

      service.start();
      async.elapse(const Duration(minutes: 3));
      service.stop();
      async.elapse(const Duration(minutes: 10));

      expect(timeouts, 0);
    });
  });
}
