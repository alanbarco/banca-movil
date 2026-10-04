import 'dart:typed_data';

import 'package:bi_app/core/fault_injection/fault_config.dart';
import 'package:bi_app/core/flags/remote_config_service.dart';
import 'package:bi_app/core/network/dio_factory.dart';
import 'package:bi_app/features/fx/data/datasources/fx_remote_datasource.dart';
import 'package:bi_app/features/fx/data/models/fx_config.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRemoteConfig extends Mock implements RemoteConfigService {}

/// Responde siempre [body] y recuerda la última URL pedida.
class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.body);

  final String body;
  Uri? lastUri;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastUri = options.uri;
    return ResponseBody.fromString(
      body,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _FakeDioFactory extends DioFactory {
  _FakeDioFactory(this.adapter);

  final HttpClientAdapter adapter;
  final created = <String>[];

  @override
  Dio create({
    required String baseUrl,
    Duration timeout = const Duration(seconds: 8),
    FaultTarget faultTarget = FaultTarget.fx,
  }) {
    created.add(baseUrl);
    return Dio(BaseOptions(baseUrl: baseUrl, receiveTimeout: timeout))
      ..httpClientAdapter = adapter;
  }
}

void main() {
  test('FxConfig usa defaults ante campos inválidos', () {
    final config = FxConfig.fromJson({
      'baseUrl': 'http://inseguro.test',
      'symbols': <Object>[],
      'timeoutMs': -1,
    });

    expect(config, const FxConfig());
  });

  test('pide /latest con base y symbols de fx_config', () async {
    final adapter = _RecordingAdapter('{"base":"USD"}');
    final factory = _FakeDioFactory(adapter);
    final remoteConfig = _MockRemoteConfig();
    when(() => remoteConfig.getJson(RemoteConfigKeys.fxConfig)).thenReturn({
      'schemaVersion': 1,
      'baseUrl': 'https://fx.test/v1',
      'symbols': ['EUR', 'JPY'],
      'timeoutMs': 3000,
    });
    final datasource = FxRemoteDatasource(
      dioFactory: factory,
      remoteConfig: remoteConfig,
    );

    final config = datasource.config;
    final json = await datasource.fetchLatest(config);
    await datasource.fetchLatest(config);

    expect(json, {'base': 'USD'});
    expect(
      adapter.lastUri.toString(),
      'https://fx.test/v1/latest?base=USD&symbols=EUR%2CJPY',
    );
    expect(factory.created, ['https://fx.test/v1'], reason: 'reutiliza Dio');
  });

  test('cuerpo que no es objeto JSON lanza FormatException', () async {
    final datasource = FxRemoteDatasource(
      dioFactory: _FakeDioFactory(_RecordingAdapter('[1, 2]')),
      remoteConfig: _MockRemoteConfig(),
    );

    expect(
      () => datasource.fetchLatest(const FxConfig()),
      throwsFormatException,
    );
  });
}
