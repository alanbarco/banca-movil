import 'package:dio/dio.dart';

import '../fault_injection/fault_config.dart';
import 'fault_interceptor.dart';
import 'retry_interceptor.dart';

/// Crea clientes HTTP con timeout, reintentos y simulador de fallos.
///
/// La base URL y el timeout llegan desde Remote Config (`fx_config`), por eso
/// se crean bajo demanda en lugar de registrarse como instancia única.
class DioFactory {
  const DioFactory({FaultConfigSource? faults, Sleep? retrySleep})
    : _faults = faults,
      _retrySleep = retrySleep;

  final FaultConfigSource? _faults;

  /// Solo para tests: evita esperar el backoff real.
  final Sleep? _retrySleep;

  Dio create({
    required String baseUrl,
    Duration timeout = const Duration(seconds: 8),
    FaultTarget faultTarget = FaultTarget.fx,
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: timeout,
        receiveTimeout: timeout,
        sendTimeout: timeout,
        responseType: ResponseType.json,
      ),
    );
    final faults = _faults;
    dio.interceptors.addAll([
      if (faults != null) FaultInterceptor(faults, target: faultTarget),
      RetryInterceptor(dio, sleep: _retrySleep),
    ]);
    return dio;
  }
}
