import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app/app.dart';
import 'app/app_config.dart';
import 'app/di.dart';
import 'app/route_guard.dart';
import 'app/router.dart';
import 'core/flags/feature_flag_service.dart';
import 'core/flags/remote_config_service.dart';
import 'core/observability/firebase_observability_service.dart';
import 'core/routing/pending_route_store.dart';
import 'core/session/current_user_profile.dart';
import 'core/session/session_status.dart';
import 'core/session/session_timeout_service.dart';
import 'core/storage/local_storage.dart';
import 'core/storage/storage_keys.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final crashlytics = FirebaseCrashlytics.instance;
  await crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode);
  FlutterError.onError = crashlytics.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    unawaited(crashlytics.recordError(error, stack, fatal: true));
    return true;
  };

  final storage = await LocalStorage.create();
  await _configureFirestore(storage);

  final observability = FirebaseObservabilityService();
  final remoteConfig = RemoteConfigService(observability: observability);
  await remoteConfig.initialize();

  configureDependencies(
    storage: storage,
    observability: observability,
    remoteConfig: remoteConfig,
    firestore: FirebaseFirestore.instance,
  );

  final router = _buildRouter(remoteConfig);
  for (final module in featureModules) {
    module.onAppReady(router);
  }
  runApp(BiApp(router: router));
}

/// Persistencia offline activada y, si el cliente cerró sesión, caché
/// borrada antes de cualquier lectura (FR-008).
Future<void> _configureFirestore(LocalStorage storage) async {
  final firestore = FirebaseFirestore.instance;
  firestore.settings = const Settings(persistenceEnabled: true);
  if (storage.getBool(StorageKeys.pendingCacheClear) ?? false) {
    await firestore.clearPersistence();
    await storage.remove(StorageKeys.pendingCacheClear);
  }
}

String? _currentSegment() => getIt.isRegistered<CurrentUserProfile>()
    ? getIt<CurrentUserProfile>().current?.segment
    : null;

GoRouter _buildRouter(RemoteConfigService remoteConfig) {
  final session = getIt<SessionStatusSource>();
  final flags = getIt<FeatureFlagService>();
  return createRouter(
    guard: RouteGuard(
      session: session,
      flags: flags,
      currentSegment: _currentSegment,
      pendingRoutes: getIt<PendingRouteStore>(),
      demoTools: AppConfig.demoTools,
    ),
    sessionTimeout: getIt<SessionTimeoutService>(),
    modules: featureModules,
    refreshOn: [session.changes, flags.changes],
    splashDebugInfo: () => _configSummary(remoteConfig),
  );
}

String _configSummary(RemoteConfigService remoteConfig) {
  final remote = RemoteConfigKeys.all.where(remoteConfig.isRemoteValue);
  final terms = remoteConfig.getJson(RemoteConfigKeys.terms)['version'];
  return 'Remote Config: ${remote.length}/${RemoteConfigKeys.all.length} '
      'parámetros remotos · términos $terms';
}
