import 'dart:typed_data';

import 'package:bi_app/core/fault_injection/fault_config.dart';
import 'package:bi_app/core/network/dio_factory.dart';
import 'package:bi_app/core/network/retry_interceptor.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Adaptador HTTP que responde según una secuencia programada.
class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this._responses);

  /// Cada entrada es un status code o un [DioExceptionType] a lanzar.
  final List<Object> _responses;
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final next =
        _responses[calls < _responses.length ? calls : _responses.length - 1];
    calls++;
    if (next is DioExceptionType) {
      throw DioException(requestOptions: options, type: next);
    }
    return ResponseBody.fromString(
      '{"ok":true}',
      next as int,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _FixedFaults implements FaultConfigSource {
  _FixedFaults(this.config);

  FaultConfig config;

  @override
  FaultConfig configFor(FaultTarget target) => config;
}

void main() {
  late Dio dio;
  late List<Duration> sleeps;

  Dio buildDio(List<Object> responses) {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    dio.httpClientAdapter = _ScriptedAdapter(responses);
    dio.interceptors.add(
      RetryInterceptor(dio, sleep: (d) async => sleeps.add(d)),
    );
    return dio;
  }

  int callsOf(Dio dio) => (dio.httpClientAdapter as _ScriptedAdapter).calls;

  setUp(() => sleeps = []);

  test(
    'reintenta un GET 3 veces con esperas 0.5 s / 1 s / 2 s ante 5xx',
    () async {
      dio = buildDio([500, 502, 503, 500]);

      await expectLater(
        dio.get<dynamic>('/latest'),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'status',
            500,
          ),
        ),
      );

      expect(callsOf(dio), 4);
      expect(sleeps, const [
        Duration(milliseconds: 500),
        Duration(seconds: 1),
        Duration(seconds: 2),
      ]);
    },
  );

  test('se recupera si un reintento tiene éxito', () async {
    dio = buildDio([503, 200]);

    final response = await dio.get<dynamic>('/latest');

    expect(response.statusCode, 200);
    expect(callsOf(dio), 2);
    expect(sleeps, const [Duration(milliseconds: 500)]);
  });

  for (final type in [
    DioExceptionType.connectionTimeout,
    DioExceptionType.receiveTimeout,
    DioExceptionType.connectionError,
  ]) {
    test('reintenta ante ${type.name}', () async {
      dio = buildDio([type, type, 200]);

      final response = await dio.get<dynamic>('/latest');

      expect(response.statusCode, 200);
      expect(callsOf(dio), 3);
    });
  }

  test('no reintenta errores 4xx', () async {
    dio = buildDio([404]);

    await expectLater(
      dio.get<dynamic>('/latest'),
      throwsA(isA<DioException>()),
    );

    expect(callsOf(dio), 1);
    expect(sleeps, isEmpty);
  });

  test('no reintenta POST aunque falle con 5xx', () async {
    dio = buildDio([500]);

    await expectLater(
      dio.post<dynamic>('/transfer', data: {'a': 1}),
      throwsA(isA<DioException>()),
    );

    expect(callsOf(dio), 1);
    expect(sleeps, isEmpty);
  });

  group('DioFactory + FaultInterceptor', () {
    Dio buildFaulty(FaultMode mode, _ScriptedAdapter adapter) {
      final factory = DioFactory(
        faults: _FixedFaults(FaultConfig(mode: mode)),
        retrySleep: (d) async => sleeps.add(d),
      );
      return factory.create(baseUrl: 'https://example.test')
        ..httpClientAdapter = adapter;
    }

    test('modo error simula 503 y pasa por los reintentos', () async {
      final adapter = _ScriptedAdapter([200]);
      final faulty = buildFaulty(FaultMode.error, adapter);

      await expectLater(
        faulty.get<dynamic>('/latest'),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'status',
            503,
          ),
        ),
      );
      expect(adapter.calls, 0);
      expect(sleeps, hasLength(3));
    });

    test('modo offline lanza connectionError con la causa simulada', () async {
      final faulty = buildFaulty(FaultMode.offline, _ScriptedAdapter([200]));

      await expectLater(
        faulty.get<dynamic>('/latest'),
        throwsA(
          isA<DioException>()
              .having((e) => e.type, 'type', DioExceptionType.connectionError)
              .having((e) => e.error, 'error', isA<SimulatedFaultException>()),
        ),
      );
    });

    test('sin fallo configurado la petición llega al adaptador', () async {
      final faults = _FixedFaults(FaultConfig.normal);
      final dio = DioFactory(faults: faults).create(
        baseUrl: 'https://example.test',
        timeout: const Duration(seconds: 3),
      );
      final adapter = _ScriptedAdapter([200]);
      dio.httpClientAdapter = adapter;

      final response = await dio.get<dynamic>('/latest');

      expect(response.statusCode, 200);
      expect(adapter.calls, 1);
      expect(dio.options.connectTimeout, const Duration(seconds: 3));
    });
  });
}
