import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get_it/get_it.dart';

import '../core/connectivity/connectivity_cubit.dart';
import '../core/connectivity/connectivity_status.dart';

import '../core/fault_injection/fault_config.dart';
import '../core/fault_injection/fault_injection_cubit.dart';
import '../core/fault_injection/fault_runner.dart';
import '../core/flags/feature_flag_service.dart';
import '../core/flags/remote_config_feature_flag_service.dart';
import '../core/flags/remote_config_service.dart';
import '../core/modules/feature_module.dart';
import '../core/network/dio_factory.dart';
import '../core/observability/observability_service.dart';
import '../core/routing/pending_route_store.dart';
import '../core/sdui/section_registry.dart';
import '../core/session/session_events.dart';
import '../core/session/session_status.dart';
import '../core/session/session_timeout_service.dart';
import '../core/storage/local_storage.dart';
import '../features/accounts/accounts_module.dart';
import '../features/auth/auth_module.dart';
import '../features/personalization/personalization_module.dart';
import 'app_config.dart';

final getIt = GetIt.instance;

/// Módulos de las features, en orden de registro. Cada historia agrega el
/// suyo (US1: auth, US2: accounts, US3: personalization, …).
const featureModules = <FeatureModule>[
  AuthModule(),
  AccountsModule(),
  PersonalizationModule(),
];

/// Registra `core` y luego las features. Los servicios que requieren
/// inicialización asíncrona llegan ya inicializados desde `main`.
void configureDependencies({
  required LocalStorage storage,
  required ObservabilityService observability,
  required RemoteConfigService remoteConfig,
  FirebaseFirestore? firestore,
  List<FeatureModule> modules = featureModules,
}) {
  getIt
    ..registerSingleton<LocalStorage>(storage)
    ..registerSingleton<ObservabilityService>(observability)
    ..registerSingleton<RemoteConfigService>(remoteConfig)
    ..registerLazySingleton<FeatureFlagService>(
      () => RemoteConfigFeatureFlagService(
        remoteConfig: getIt(),
        observability: getIt(),
      ),
    )
    ..registerLazySingleton<SectionRegistry>(SectionRegistry.new)
    ..registerLazySingleton<SessionTimeoutService>(SessionTimeoutService.new)
    ..registerLazySingleton<SessionEvents>(SessionEvents.new)
    ..registerLazySingleton<PendingRouteStore>(PendingRouteStore.new)
    ..registerLazySingleton<FaultInjectionCubit>(
      () => FaultInjectionCubit(firestore: firestore),
    )
    // Una sola instancia: el banner global y las features ven lo mismo.
    ..registerLazySingleton<ConnectivityCubit>(() {
      final cubit = ConnectivityCubit(
        connectivity: Connectivity(),
        observability: getIt(),
        forcedOfflineChanges: getIt<FaultInjectionCubit>().stream
            .map((state) => state.forcedOffline)
            .distinct(),
      );
      unawaited(cubit.start());
      return cubit;
    })
    ..registerLazySingleton<ConnectivityStatus>(
      () => getIt<ConnectivityCubit>(),
    )
    // El simulador solo se conecta a datos y red en builds de demo.
    ..registerLazySingleton<FaultRunner>(
      () => FaultRunner(
        AppConfig.demoTools ? getIt<FaultInjectionCubit>() : const NoFaults(),
      ),
    )
    ..registerLazySingleton<DioFactory>(
      () => DioFactory(
        faults: AppConfig.demoTools ? getIt<FaultInjectionCubit>() : null,
      ),
    );

  registerFeatures(modules);

  // Hasta que `auth` (US1) registre la suya, la sesión queda sin resolver.
  if (!getIt.isRegistered<SessionStatusSource>()) {
    getIt.registerSingleton<SessionStatusSource>(
      const UnresolvedSessionStatusSource(),
    );
  }
}

void registerFeatures(List<FeatureModule> modules) {
  for (final module in modules) {
    module.register(getIt);
  }
}
