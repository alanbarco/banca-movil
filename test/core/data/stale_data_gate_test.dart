import 'package:bi_app/core/data/stale_data_gate.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_connectivity.dart';

void main() {
  late FakeConnectivity connectivity;
  late int changes;

  StaleDataGate build() =>
      StaleDataGate(connectivity: connectivity, onChange: () => changes++);

  setUp(() {
    connectivity = FakeConnectivity();
    changes = 0;
  });

  test('caché confirmada por el servidor antes de 5 s: sin aviso', () {
    fakeAsync((async) {
      final gate = build()..track(fromCache: true);
      expect(gate.showStale, isFalse);

      async.elapse(const Duration(milliseconds: 300));
      gate.track(fromCache: false);
      async.elapse(const Duration(seconds: 10));

      expect(gate.showStale, isFalse);
      expect(changes, 0);
    });
  });

  test('caché sin confirmar durante 5 s: aviso', () {
    fakeAsync((async) {
      final gate = build()..track(fromCache: true);

      async.elapse(const Duration(milliseconds: 4999));
      expect(gate.showStale, isFalse);
      async.elapse(const Duration(milliseconds: 1));

      expect(gate.showStale, isTrue);
      expect(changes, 1);
    });
  });

  test('nuevos snapshots de caché no reinician la espera', () {
    fakeAsync((async) {
      final gate = build()..track(fromCache: true);
      async.elapse(const Duration(seconds: 3));
      gate.track(fromCache: true);
      async.elapse(const Duration(seconds: 2));

      expect(gate.showStale, isTrue);
    });
  });

  test('sin conexión real: aviso inmediato', () {
    fakeAsync((async) {
      connectivity.setOnline(false);
      final gate = build()..track(fromCache: true);

      expect(gate.showStale, isTrue);
    });
  });

  test('perder la conexión con datos de caché avisa al instante', () {
    fakeAsync((async) {
      final gate = build()..track(fromCache: true);

      connectivity.setOnline(false);

      expect(changes, 1);
      expect(gate.showStale, isTrue);
    });
  });

  test('datos del servidor nunca se marcan, aun sin conexión', () {
    fakeAsync((async) {
      connectivity.setOnline(false);
      final gate = build()..track(fromCache: false);
      async.elapse(const Duration(seconds: 10));

      expect(gate.showStale, isFalse);
    });
  });

  test('dispose cancela la espera y la escucha de conectividad', () {
    fakeAsync((async) {
      final gate = build()..track(fromCache: true);
      gate.dispose();

      async.elapse(const Duration(seconds: 10));
      connectivity.setOnline(false);

      expect(changes, 0);
    });
  });
}
