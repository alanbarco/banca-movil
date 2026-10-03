import 'dart:async';

import 'package:bi_app/core/connectivity/connectivity_cubit.dart';
import 'package:bi_app/core/observability/analytics_events.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fake_observability.dart';

class _MockConnectivity extends Mock implements Connectivity {}

void main() {
  late _MockConnectivity connectivity;
  late StreamController<List<ConnectivityResult>> changes;
  late StreamController<bool> forced;
  late FakeObservabilityService observability;

  setUp(() {
    connectivity = _MockConnectivity();
    changes = StreamController<List<ConnectivityResult>>();
    forced = StreamController<bool>();
    observability = FakeObservabilityService();
    when(
      () => connectivity.onConnectivityChanged,
    ).thenAnswer((_) => changes.stream);
    when(
      () => connectivity.checkConnectivity(),
    ).thenAnswer((_) async => [ConnectivityResult.wifi]);
  });

  tearDown(() async {
    await changes.close();
    await forced.close();
  });

  ConnectivityCubit build() => ConnectivityCubit(
    connectivity: connectivity,
    observability: observability,
    forcedOfflineChanges: forced.stream,
  );

  List<bool> onlineEvents() => observability
      .named(AnalyticsEvents.connectivityChanged)
      .map((e) => e.parameters[AnalyticsParams.online]! as bool)
      .toList();

  blocTest<ConnectivityCubit, ConnectivityState>(
    'online → offline → online y emite connectivity_changed en cada cambio',
    build: build,
    act: (cubit) async {
      await cubit.start();
      changes.add([ConnectivityResult.none]);
      await Future<void>.delayed(Duration.zero);
      changes.add([ConnectivityResult.mobile]);
    },
    expect: () => const [
      ConnectivityState(deviceOnline: false),
      ConnectivityState(),
    ],
    verify: (_) => expect(onlineEvents(), [false, true]),
  );

  blocTest<ConnectivityCubit, ConnectivityState>(
    'arranca sin conexión si el sistema lo reporta',
    setUp: () => when(
      () => connectivity.checkConnectivity(),
    ).thenAnswer((_) async => [ConnectivityResult.none]),
    build: build,
    act: (cubit) => cubit.start(),
    expect: () => const [ConnectivityState(deviceOnline: false)],
    verify: (cubit) {
      expect(cubit.state.isOnline, isFalse);
      expect(onlineEvents(), [false]);
    },
  );

  blocTest<ConnectivityCubit, ConnectivityState>(
    'el modo offline del simulador fuerza el estado sin conexión',
    build: build,
    act: (cubit) async {
      await cubit.start();
      forced.add(true);
      await Future<void>.delayed(Duration.zero);
      forced.add(false);
    },
    expect: () => const [
      ConnectivityState(forcedOffline: true),
      ConnectivityState(),
    ],
    verify: (_) => expect(onlineEvents(), [false, true]),
  );

  blocTest<ConnectivityCubit, ConnectivityState>(
    'no emite evento si el estado efectivo no cambia',
    build: build,
    act: (cubit) async {
      await cubit.start();
      changes.add([ConnectivityResult.none]);
      await Future<void>.delayed(Duration.zero);
      // Ya estaba offline por el dispositivo: forzar no cambia `isOnline`.
      forced.add(true);
      await Future<void>.delayed(Duration.zero);
      changes.add([ConnectivityResult.wifi, ConnectivityResult.vpn]);
    },
    expect: () => const [
      ConnectivityState(deviceOnline: false),
      ConnectivityState(deviceOnline: false, forcedOffline: true),
      ConnectivityState(forcedOffline: true),
    ],
    verify: (_) => expect(onlineEvents(), [false]),
  );
}
