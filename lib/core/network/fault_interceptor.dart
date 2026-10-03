import 'package:dio/dio.dart';

import '../fault_injection/fault_config.dart';

/// Inyecta los fallos simulados del panel de demo en las peticiones HTTP.
///
/// Los rechazos continúan por los interceptores de error para que el
/// `RetryInterceptor` se comporte igual que ante un fallo real.
class FaultInterceptor extends Interceptor {
  FaultInterceptor(this._source, {this.target = FaultTarget.fx});

  final FaultConfigSource _source;
  final FaultTarget target;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final config = _source.configFor(target);
    switch (config.mode) {
      case FaultMode.none:
        handler.next(options);
      case FaultMode.latency:
        await Future<void>.delayed(config.latency);
        handler.next(options);
      case FaultMode.offline:
        handler.reject(
          DioException.connectionError(
            requestOptions: options,
            reason: 'simulated offline',
            error: SimulatedFaultException(target, FaultMode.offline),
          ),
          true,
        );
      case FaultMode.error:
        handler.reject(
          DioException.badResponse(
            statusCode: 503,
            requestOptions: options,
            response: Response<void>(requestOptions: options, statusCode: 503),
          ),
          true,
        );
    }
  }
}
