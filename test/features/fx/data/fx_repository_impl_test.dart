import 'package:bi_app/core/error/failure.dart';
import 'package:bi_app/core/observability/analytics_events.dart';
import 'package:bi_app/core/storage/local_storage.dart';
import 'package:bi_app/features/fx/data/datasources/fx_local_cache.dart';
import 'package:bi_app/features/fx/data/datasources/fx_remote_datasource.dart';
import 'package:bi_app/features/fx/data/models/fx_config.dart';
import 'package:bi_app/features/fx/data/repositories/fx_repository_impl.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/fake_observability.dart';
import '../fx_fixtures.dart';

class _MockRemote extends Mock implements FxRemoteDatasource {}

DioException _dioError(DioExceptionType type, {int? status}) {
  final options = RequestOptions(path: '/latest');
  return DioException(
    requestOptions: options,
    type: type,
    response: status == null
        ? null
        : Response<void>(requestOptions: options, statusCode: status),
  );
}

void main() {
  late _MockRemote remote;
  late FxLocalCache cache;
  late FakeObservabilityService observability;
  late FxRepositoryImpl repository;

  setUpAll(() => registerFallbackValue(const FxConfig()));

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    cache = FxLocalCache(await LocalStorage.create());
    remote = _MockRemote();
    observability = FakeObservabilityService();
    when(() => remote.config).thenReturn(const FxConfig());
    repository = FxRepositoryImpl(
      remote: remote,
      cache: cache,
      observability: observability,
      clock: () => fetchedAt,
    );
  });

  void failWith(Object error) =>
      when(() => remote.fetchLatest(any())).thenThrow(error);

  List<Object> reasons() => [
    for (final event in observability.named(AnalyticsEvents.fxServiceFailure))
      event.parameters[AnalyticsParams.reason]!,
  ];

  test('éxito: devuelve tasas frescas y las guarda en caché', () async {
    when(
      () => remote.fetchLatest(any()),
    ).thenAnswer((_) async => frankfurterJson);

    final snapshot = (await repository.latest()).valueOrNull!;

    expect(snapshot.data, rates);
    expect(snapshot.isStale, isFalse);
    expect(snapshot.lastSyncedAt, fetchedAt);
    expect(cache.read(expectedBase: 'USD'), rates);
    expect(reasons(), isEmpty);
  });

  test('falla con caché: devuelve la caché marcada isStale', () async {
    await cache.write(rates);
    failWith(_dioError(DioExceptionType.connectionTimeout));

    final snapshot = (await repository.latest()).valueOrNull!;

    expect(snapshot.data, rates);
    expect(snapshot.isStale, isTrue);
    expect(snapshot.lastSyncedAt, fetchedAt);
    expect(reasons(), ['timeout']);
  });

  test('falla sin caché: Err con la causa', () async {
    failWith(_dioError(DioExceptionType.connectionError));

    final result = await repository.latest();

    expect(result.failureOrNull, const Failure.network());
    expect(reasons(), ['network']);
  });

  test('base distinta de USD es una respuesta inválida', () async {
    when(
      () => remote.fetchLatest(any()),
    ).thenAnswer((_) async => {...frankfurterJson, 'base': 'EUR'});

    final result = await repository.latest();

    expect(result.failureOrNull, const Failure.server());
    expect(reasons(), ['invalid']);
    expect(cache.read(expectedBase: 'USD'), isNull);
  });

  test('clasifica la causa de cada falla', () {
    expect(
      FxRepositoryImpl.reasonFor(
        _dioError(DioExceptionType.badResponse, status: 503),
      ),
      'http_5xx',
    );
    expect(
      FxRepositoryImpl.reasonFor(
        _dioError(DioExceptionType.badResponse, status: 404),
      ),
      'http_4xx',
    );
    expect(
      FxRepositoryImpl.reasonFor(_dioError(DioExceptionType.receiveTimeout)),
      'timeout',
    );
    expect(FxRepositoryImpl.reasonFor(const FormatException('x')), 'invalid');
    expect(
      FxRepositoryImpl.failureFor(_dioError(DioExceptionType.sendTimeout)),
      const Failure.timeout(),
    );
  });
}
