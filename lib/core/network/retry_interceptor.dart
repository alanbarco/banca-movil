import 'package:dio/dio.dart';

typedef Sleep = Future<void> Function(Duration duration);

/// Reintenta consultas idempotentes con backoff exponencial (FR-030).
///
/// Solo `GET`; solo ante timeout, error de conexión o respuesta 5xx. Las
/// acciones que crean o modifican datos nunca se repiten.
class RetryInterceptor extends Interceptor {
  RetryInterceptor(this._dio, {this.delays = defaultDelays, Sleep? sleep})
    : _sleep = sleep ?? Future<void>.delayed;

  static const defaultDelays = [
    Duration(milliseconds: 500),
    Duration(seconds: 1),
    Duration(seconds: 2),
  ];

  static const _attemptKey = 'retry_attempt';

  final Dio _dio;
  final List<Duration> delays;
  final Sleep _sleep;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final attempt = (options.extra[_attemptKey] as int?) ?? 0;
    if (!_shouldRetry(err) || attempt >= delays.length) {
      handler.next(err);
      return;
    }

    await _sleep(delays[attempt]);
    options.extra[_attemptKey] = attempt + 1;
    try {
      handler.resolve(await _dio.fetch<dynamic>(options));
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  static bool _shouldRetry(DioException err) {
    if (err.requestOptions.method.toUpperCase() != 'GET') return false;
    return switch (err.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.connectionError => true,
      DioExceptionType.badResponse => (err.response?.statusCode ?? 0) >= 500,
      _ => false,
    };
  }
}
