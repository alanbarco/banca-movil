import 'package:equatable/equatable.dart';

import '../../../../core/flags/remote_config_service.dart';
import '../../domain/entities/onboarding_seed.dart';

class TermsInfo extends Equatable {
  const TermsInfo({required this.version, required this.url});

  final String version;
  final String url;

  @override
  List<Object?> get props => [version, url];
}

/// Configuración del onboarding publicada por el banco en Remote Config.
class OnboardingSeedDatasource {
  OnboardingSeedDatasource(this._remoteConfig);

  final RemoteConfigService _remoteConfig;

  /// Semilla remota; si no respeta el contrato, la del asset local.
  OnboardingSeed load() {
    return OnboardingSeed.fromJson(
          _remoteConfig.getJson(RemoteConfigKeys.onboardingSeed),
        ) ??
        OnboardingSeed.fromJson(
          _remoteConfig.localDefault(RemoteConfigKeys.onboardingSeed) ??
              const {},
        ) ??
        (throw StateError('onboarding_seed inválido también en el asset'));
  }

  TermsInfo terms() {
    final json = _remoteConfig.getJson(RemoteConfigKeys.terms);
    final version = json['version'];
    final url = json['url'];
    return TermsInfo(
      version: version is String ? version : '',
      url: url is String ? url : '',
    );
  }
}
