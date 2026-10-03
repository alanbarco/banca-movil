import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

import 'app_logger.dart';
import 'observability_service.dart';

/// Analytics para eventos y Crashlytics para errores.
///
/// En tests se usa `NoopObservabilityService`.
class FirebaseObservabilityService implements ObservabilityService {
  FirebaseObservabilityService({
    FirebaseAnalytics? analytics,
    FirebaseCrashlytics? crashlytics,
    AppLogger? logger,
  }) : _analytics = analytics ?? FirebaseAnalytics.instance,
       _crashlytics = crashlytics ?? FirebaseCrashlytics.instance,
       _logger = logger ?? AppLogger('observability');

  final FirebaseAnalytics _analytics;
  final FirebaseCrashlytics _crashlytics;
  final AppLogger _logger;

  @override
  Future<void> logEvent(String name, [Map<String, Object>? parameters]) async {
    _logger.debug('event $name', parameters ?? const {});
    await _analytics.logEvent(
      name: name,
      // Analytics solo acepta String o num.
      parameters: parameters?.map(
        (key, value) => MapEntry(key, value is num ? value : value.toString()),
      ),
    );
  }

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stackTrace, {
    String? reason,
    bool fatal = false,
  }) async {
    _logger.error(
      reason ?? 'error no controlado',
      error: error,
      stackTrace: stackTrace,
    );
    await _crashlytics.recordError(
      error,
      stackTrace,
      reason: reason,
      fatal: fatal,
    );
  }

  @override
  Future<void> setUserProperty(String name, String? value) {
    return _analytics.setUserProperty(name: name, value: value);
  }

  @override
  Future<void> setUserId(String? id) async {
    await _analytics.setUserId(id: id);
    await _crashlytics.setUserIdentifier(id ?? '');
  }
}
