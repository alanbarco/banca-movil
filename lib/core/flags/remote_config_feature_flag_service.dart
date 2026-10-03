import 'dart:async';

import '../observability/analytics_events.dart';
import '../observability/observability_service.dart';
import 'feature_flag_service.dart';
import 'feature_flags.dart';
import 'remote_config_service.dart';

/// Flags leídos de `feature_flags` con los defaults del asset como respaldo.
class RemoteConfigFeatureFlagService implements FeatureFlagService {
  RemoteConfigFeatureFlagService({
    required RemoteConfigService remoteConfig,
    required ObservabilityService observability,
  }) : _remoteConfig = remoteConfig,
       _observability = observability,
       _localDefaults = FeatureFlags.fromJson(
         remoteConfig.localDefault(RemoteConfigKeys.featureFlags) ?? const {},
       ) {
    _reload();
    _subscription = _remoteConfig.updates
        .where((keys) => keys.contains(RemoteConfigKeys.featureFlags))
        .listen((_) {
          _reload();
          _changes.add(null);
        });
  }

  final RemoteConfigService _remoteConfig;
  final ObservabilityService _observability;
  final FeatureFlags _localDefaults;
  final Map<String, bool> _lastLogged = {};
  final _changes = StreamController<void>.broadcast();
  late final StreamSubscription<Set<String>> _subscription;
  late FeatureFlags _flags;

  @override
  Stream<void> get changes => _changes.stream;

  @override
  bool isEnabled(String key, {String? segment}) {
    final enabled = _flags.isEnabled(
      key,
      segment: segment,
      defaults: _localDefaults,
    );
    _logIfChanged(key, segment, enabled);
    return enabled;
  }

  void _reload() {
    _flags = FeatureFlags.fromJson(
      _remoteConfig.getJson(RemoteConfigKeys.featureFlags),
    );
  }

  // Un evento por cambio de valor, no por cada evaluación.
  void _logIfChanged(String key, String? segment, bool enabled) {
    final cacheKey = '$key|$segment';
    if (_lastLogged[cacheKey] == enabled) return;
    _lastLogged[cacheKey] = enabled;
    unawaited(
      _observability.logEvent(AnalyticsEvents.featureFlagEvaluated, {
        AnalyticsParams.flag: key,
        AnalyticsParams.enabled: enabled,
      }),
    );
  }

  Future<void> dispose() async {
    await _subscription.cancel();
    await _changes.close();
  }
}
