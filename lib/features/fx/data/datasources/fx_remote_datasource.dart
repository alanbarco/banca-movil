import 'package:dio/dio.dart';

import '../../../../core/flags/remote_config_service.dart';
import '../../../../core/network/dio_factory.dart';
import '../models/fx_config.dart';

/// `GET {baseUrl}/latest?base=USD&symbols=…` (`contracts/fx-external-api.md`).
///
/// Timeout, reintentos y simulador de fallos vienen de [DioFactory]. La
/// config se lee en cada petición para respetar cambios de Remote Config.
class FxRemoteDatasource {
  FxRemoteDatasource({
    required DioFactory dioFactory,
    required RemoteConfigService remoteConfig,
  }) : _dioFactory = dioFactory,
       _remoteConfig = remoteConfig;

  final DioFactory _dioFactory;
  final RemoteConfigService _remoteConfig;

  Dio? _dio;
  FxConfig? _dioConfig;

  FxConfig get config =>
      FxConfig.fromJson(_remoteConfig.getJson(RemoteConfigKeys.fxConfig));

  /// Lanza `DioException` ante fallos de red/HTTP y `FormatException` si el
  /// cuerpo no es un objeto JSON.
  Future<Map<String, dynamic>> fetchLatest(FxConfig config) async {
    final response = await _dioFor(config).get<Object?>(
      '/latest',
      queryParameters: {
        'base': config.base,
        'symbols': config.symbols.join(','),
      },
    );
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const FormatException('fx: la respuesta no es un objeto JSON');
    }
    return data;
  }

  /// Reutiliza el cliente mientras la base URL y el timeout no cambien.
  Dio _dioFor(FxConfig config) {
    final current = _dio;
    if (current != null &&
        _dioConfig?.baseUrl == config.baseUrl &&
        _dioConfig?.timeout == config.timeout) {
      return current;
    }
    current?.close();
    _dioConfig = config;
    return _dio = _dioFactory.create(
      baseUrl: config.baseUrl,
      timeout: config.timeout,
    );
  }
}
