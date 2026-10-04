import '../../../../core/flags/remote_config_service.dart';

/// Parámetro `home_layout` de Remote Config y sus actualizaciones en vivo.
class HomeLayoutRemoteConfigDatasource {
  HomeLayoutRemoteConfigDatasource(this._remoteConfig);

  final RemoteConfigService _remoteConfig;

  /// Valor activo validado (o el último válido); nunca lanza.
  Map<String, dynamic> read() =>
      _remoteConfig.getJson(RemoteConfigKeys.homeLayout);

  Map<String, dynamic> localDefaults() =>
      _remoteConfig.localDefault(RemoteConfigKeys.homeLayout) ?? const {};

  /// Emite cuando el banco publica un `home_layout` nuevo.
  Stream<void> get changes => _remoteConfig.updates
      .where((keys) => keys.contains(RemoteConfigKeys.homeLayout))
      .map((_) {});

  Future<void> refresh() => _remoteConfig.refresh();
}
