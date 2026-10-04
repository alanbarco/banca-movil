import 'dart:async';
import 'dart:convert';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../observability/app_logger.dart';
import '../observability/observability_service.dart';
import 'versioned_json.dart';

/// Claves de los parámetros de `contracts/remote-config.md`.
abstract final class RemoteConfigKeys {
  static const homeLayout = 'home_layout';
  static const featureFlags = 'feature_flags';
  static const onboardingSeed = 'onboarding_seed';
  static const fxConfig = 'fx_config';
  static const terms = 'terms';

  static const all = [
    homeLayout,
    featureFlags,
    onboardingSeed,
    fxConfig,
    terms,
  ];
}

/// Configuración remota con defaults locales seguros (FR-017).
///
/// Cada parámetro JSON se valida (`schemaVersion`); si el valor remoto es
/// inválido se usa el último valor válido conocido y se registra el incidente.
class RemoteConfigService {
  RemoteConfigService({
    required ObservabilityService observability,
    FirebaseRemoteConfig? remoteConfig,
    AssetBundle? bundle,
    AppLogger? logger,
  }) : _observability = observability,
       _remoteConfig = remoteConfig ?? FirebaseRemoteConfig.instance,
       _bundle = bundle ?? rootBundle,
       _logger = logger ?? AppLogger('remote_config');

  static const defaultsAsset = 'assets/config/remote_config_defaults.json';

  final ObservabilityService _observability;
  final FirebaseRemoteConfig _remoteConfig;
  final AssetBundle _bundle;
  final AppLogger _logger;

  final Map<String, Map<String, dynamic>> _localDefaults = {};
  final Map<String, Map<String, dynamic>> _lastValid = {};
  final _updates = StreamController<Set<String>>.broadcast();
  StreamSubscription<RemoteConfigUpdate>? _realtime;

  /// Claves que cambiaron tras activar una actualización remota.
  Stream<Set<String>> get updates => _updates.stream;

  /// Valor del asset local (disponible tras [initialize]).
  Map<String, dynamic>? localDefault(String key) => _localDefaults[key];

  Future<void> initialize() async {
    final defaults = await _loadLocalDefaults();
    _localDefaults.addAll(defaults);
    _lastValid.addAll(defaults);
    await _remoteConfig.setDefaults({
      for (final entry in defaults.entries) entry.key: jsonEncode(entry.value),
    });
    await _remoteConfig.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: kReleaseMode
            ? const Duration(minutes: 5)
            : Duration.zero,
      ),
    );

    try {
      await _remoteConfig.fetchAndActivate();
    } on Object catch (error, stackTrace) {
      // Sin red o fetch fallido: se sigue con defaults / último activado.
      _logger.warning('fetchAndActivate falló', {'error': error.toString()});
      unawaited(
        _observability.recordError(
          error,
          stackTrace,
          reason: 'remote_config_fetch',
        ),
      );
    }

    _logger.info('Remote Config listo', {
      'remote': RemoteConfigKeys.all.where(isRemoteValue).join(','),
    });

    _realtime = _remoteConfig.onConfigUpdated.listen(
      _onConfigUpdated,
      onError: (Object error, StackTrace stackTrace) {
        _logger.warning('listener en tiempo real falló', {
          'error': error.toString(),
        });
      },
    );
  }

  /// `true` si el valor activo de [key] vino de la consola (no del default).
  bool isRemoteValue(String key) =>
      _remoteConfig.getValue(key).source == ValueSource.valueRemote;

  /// Parámetro JSON validado; nunca lanza.
  Map<String, dynamic> getJson(String key) {
    final raw = _remoteConfig.getString(key);
    final decoded = decodeVersionedJson(raw);
    if (decoded != null) {
      _lastValid[key] = decoded;
      return decoded;
    }

    _logger.warning('parámetro inválido, se usa el último válido', {
      'key': key,
    });
    unawaited(
      _observability.recordError(
        StateError('Remote Config inválido: $key'),
        StackTrace.current,
        reason: 'remote_config_invalid',
      ),
    );
    return _lastValid[key] ?? const {'schemaVersion': supportedSchemaVersion};
  }

  /// Pide la configuración al servidor (pull-to-refresh). Si se activó algo
  /// nuevo, avisa a los suscriptores de [updates]. Puede lanzar sin red.
  Future<void> refresh() async {
    final activated = await _remoteConfig.fetchAndActivate();
    if (activated) _updates.add(RemoteConfigKeys.all.toSet());
  }

  Future<void> _onConfigUpdated(RemoteConfigUpdate update) async {
    await _remoteConfig.activate();
    _logger.info('configuración actualizada', {
      'keys': update.updatedKeys.join(','),
    });
    _updates.add(update.updatedKeys);
  }

  Future<Map<String, Map<String, dynamic>>> _loadLocalDefaults() async {
    final raw = await _bundle.loadString(defaultsAsset);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return {
      for (final entry in decoded.entries)
        if (entry.value is Map<String, dynamic>)
          entry.key: entry.value as Map<String, dynamic>,
    };
  }

  Future<void> dispose() async {
    await _realtime?.cancel();
    await _updates.close();
  }
}
