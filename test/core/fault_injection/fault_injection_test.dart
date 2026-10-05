import 'package:bi_app/core/fault_injection/fault_config.dart';
import 'package:bi_app/core/fault_injection/fault_injection_cubit.dart';
import 'package:bi_app/core/fault_injection/fault_runner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockFirestore extends Mock implements FirebaseFirestore {}

void main() {
  group('FaultInjectionCubit', () {
    late _MockFirestore firestore;
    late FaultInjectionCubit cubit;

    setUp(() {
      firestore = _MockFirestore();
      when(() => firestore.disableNetwork()).thenAnswer((_) async {});
      when(() => firestore.enableNetwork()).thenAnswer((_) async {});
      cubit = FaultInjectionCubit(firestore: firestore);
    });

    tearDown(() => cubit.close());

    test('offline de Firestore deshabilita y rehabilita la red real', () async {
      await cubit.setFault(FaultTarget.firestore, FaultMode.offline);
      expect(cubit.state.forcedOffline, isTrue);
      verify(() => firestore.disableNetwork()).called(1);

      await cubit.setFault(FaultTarget.firestore, FaultMode.offline);
      verifyNever(() => firestore.enableNetwork());

      await cubit.reset();
      expect(cubit.state.forcedOffline, isFalse);
      verify(() => firestore.enableNetwork()).called(1);
    });

    test('error de Firestore corta la red sin el banner global', () async {
      await cubit.setFault(FaultTarget.firestore, FaultMode.error);
      expect(cubit.state.forcedOffline, isFalse);
      verify(() => firestore.disableNetwork()).called(1);

      // De error a sin red: la red ya está cortada.
      await cubit.setFault(FaultTarget.firestore, FaultMode.offline);
      verifyNever(() => firestore.enableNetwork());

      await cubit.setFault(FaultTarget.firestore, FaultMode.none);
      verify(() => firestore.enableNetwork()).called(1);
    });

    test('otros servicios no tocan la red de Firestore', () async {
      await cubit.setFault(FaultTarget.fx, FaultMode.offline);

      expect(cubit.configFor(FaultTarget.fx).mode, FaultMode.offline);
      expect(cubit.state.forcedOffline, isFalse);
      verifyNever(() => firestore.disableNetwork());
    });

    test('conserva la latencia configurada al cambiar de modo', () async {
      await cubit.setFault(
        FaultTarget.personalization,
        FaultMode.latency,
        latencyMs: 5000,
      );
      await cubit.setFault(FaultTarget.personalization, FaultMode.error);

      expect(
        cubit.configFor(FaultTarget.personalization),
        const FaultConfig(mode: FaultMode.error, latencyMs: 5000),
      );
    });
  });

  group('FaultRunner', () {
    late FaultInjectionCubit cubit;
    late FaultRunner runner;

    setUp(() {
      cubit = FaultInjectionCubit();
      runner = FaultRunner(cubit);
    });

    tearDown(() => cubit.close());

    test('sin fallo ejecuta la acción', () async {
      expect(
        await runner.runWithFaults(FaultTarget.personalization, () async => 1),
        1,
      );
    });

    test('modo error lanza SimulatedFaultException', () async {
      await cubit.setFault(FaultTarget.personalization, FaultMode.error);

      await expectLater(
        runner.runWithFaults(FaultTarget.personalization, () async => 1),
        throwsA(isA<SimulatedFaultException>()),
      );
      await expectLater(
        runner.streamWithFaults(
          FaultTarget.personalization,
          () => Stream.value(1),
        ),
        emitsError(isA<SimulatedFaultException>()),
      );
    });

    for (final mode in [FaultMode.offline, FaultMode.error]) {
      test('${mode.name} lanza salvo en Firestore, que usa su caché', () async {
        await cubit.setFault(FaultTarget.personalization, mode);
        await cubit.setFault(FaultTarget.firestore, mode);

        await expectLater(
          runner.runWithFaults(FaultTarget.personalization, () async => 1),
          throwsA(isA<SimulatedFaultException>()),
        );
        expect(
          await runner.runWithFaults(FaultTarget.firestore, () async => 2),
          2,
        );
        expect(
          await runner
              .streamWithFaults(FaultTarget.firestore, () => Stream.value(3))
              .single,
          3,
        );
      });
    }

    test('latencia retrasa la acción y el stream', () {
      fakeAsync((async) {
        cubit.setFault(
          FaultTarget.firestore,
          FaultMode.latency,
          latencyMs: 2000,
        );
        async.flushMicrotasks();

        int? value;
        final values = <int>[];
        runner
            .runWithFaults(FaultTarget.firestore, () async => 7)
            .then((v) => value = v);
        runner
            .streamWithFaults(FaultTarget.firestore, () => Stream.value(8))
            .listen(values.add);

        async.elapse(const Duration(milliseconds: 1999));
        expect(value, isNull);
        expect(values, isEmpty);

        async.elapse(const Duration(milliseconds: 1));
        expect(value, 7);
        expect(values, [8]);
      });
    });
  });
}
