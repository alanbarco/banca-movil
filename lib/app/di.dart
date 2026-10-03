import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get_it/get_it.dart';

import '../core/fault_injection/fault_injection_cubit.dart';
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
import '../features/auth/auth_module.dart';
import '../features/personalization/personalization_module.dart';
import 'app_config.dart';

final sl = GetIt.instance;

/// Módulos de las features, en orden de registro. Cada historia agrega el
/// suyo (US1: auth, US2: accounts, US3: personalization, …).
const featureModules = <FeatureModule>[AuthModule(), PersonalizationModule()];

/// Registra `core` y luego las features. Los servicios que requieren
/// inicialización asíncrona llegan ya inicializados desde `main`.
void configureDependencies({
  required LocalStorage storage,
  required ObservabilityService observability,
  required RemoteConfigService remoteConfig,
  FirebaseFirestore? firestore,
  List<FeatureModule> modules = featureModules,
}) {
  sl
    ..registerSingleton<LocalStorage>(storage)
    ..registerSingleton<ObservabilityService>(observability)
    ..registerSingleton<RemoteConfigService>(remoteConfig)
    ..registerLazySingleton<FeatureFlagService>(
      () => RemoteConfigFeatureFlagService(
        remoteConfig: sl(),
        observability: sl(),
      ),
    )
    ..registerLazySingleton<SectionRegistry>(SectionRegistry.new)
    ..registerLazySingleton<SessionTimeoutService>(SessionTimeoutService.new)
    ..registerLazySingleton<SessionEvents>(SessionEvents.new)
    ..registerLazySingleton<PendingRouteStore>(PendingRouteStore.new)
    ..registerLazySingleton<FaultInjectionCubit>(
      () => FaultInjectionCubit(firestore: firestore),
    )
    // El simulador solo se conecta a la red en builds de demo.
    ..registerLazySingleton<DioFactory>(
      () => DioFactory(
        faults: AppConfig.demoTools ? sl<FaultInjectionCubit>() : null,
      ),
    );

  registerFeatures(modules);

  // Hasta que `auth` (US1) registre la suya, la sesión queda sin resolver.
  if (!sl.isRegistered<SessionStatusSource>()) {
    sl.registerSingleton<SessionStatusSource>(
      const UnresolvedSessionStatusSource(),
    );
  }
}

void registerFeatures(List<FeatureModule> modules) {
  for (final module in modules) {
    module.register(sl);
  }
}
