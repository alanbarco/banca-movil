import 'dart:async';

import 'package:dio/dio.dart';

import '../../../../core/data/data_snapshot.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/observability/analytics_events.dart';
import '../../../../core/observability/app_logger.dart';
import '../../../../core/observability/observability_service.dart';
import '../../domain/entities/exchange_rates.dart';
import '../../domain/repositories/fx_repository.dart';
import '../datasources/fx_local_cache.dart';
import '../datasources/fx_remote_datasource.dart';
import '../models/exchange_rates_model.dart';

/// Política de `contracts/fx-external-api.md`: respuesta válida → caché;
/// falla con caché → caché `isStale`; falla sin caché → `Err`. Cada falla
/// emite `fx_service_failure` con su `reason`.
class FxRepositoryImpl implements FxRepository {
  FxRepositoryImpl({
    required FxRemoteDatasource remote,
    required FxLocalCache cache,
    required ObservabilityService observability,
    DateTime Function()? clock,
    AppLogger? logger,
  }) : _remote = remote,
       _cache = cache,
       _observability = observability,
       _clock = clock ?? DateTime.now,
       _logger = logger ?? AppLogger('fx');

  final FxRemoteDatasource _remote;
  final FxLocalCache _cache;
  final ObservabilityService _observability;
  final DateTime Function() _clock;
  final AppLogger _logger;

  @override
  Future<Result<DataSnapshot<ExchangeRates>>> latest() async {
    final config = _remote.config;
    try {
      final json = await _remote.fetchLatest(config);
      final rates = ExchangeRatesModel.fromJson(
        json,
        expectedBase: config.base,
        fetchedAt: _clock().toUtc(),
      );
      if (rates == null) throw const _InvalidResponse();
      await _cache.write(rates);
      return Success(DataSnapshot(data: rates, lastSyncedAt: rates.fetchedAt));
    } on Object catch (error) {
      final reason = reasonFor(error);
      _logger.warning('tipos de cambio no disponibles', {'reason': reason});
      unawaited(
        _observability.logEvent(AnalyticsEvents.fxServiceFailure, {
          AnalyticsParams.reason: reason,
        }),
      );

      final cached = _cache.read(expectedBase: config.base);
      if (cached != null) {
        return Success(
          DataSnapshot(
            data: cached,
            isStale: true,
            lastSyncedAt: cached.fetchedAt,
          ),
        );
      }
      return Err(failureFor(error));
    }
  }

  /// `reason` de `fx_service_failure`: timeout, http_5xx, http_4xx, network
  /// o invalid.
  static String reasonFor(Object error) {
    if (error is DioException) {
      return switch (error.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout => 'timeout',
        DioExceptionType.badResponse =>
          (error.response?.statusCode ?? 0) >= 500 ? 'http_5xx' : 'http_4xx',
        _ => 'network',
      };
    }
    return 'invalid';
  }

  static Failure failureFor(Object error) => switch (reasonFor(error)) {
    'timeout' => const Failure.timeout(),
    'network' => const Failure.network(),
    _ => const Failure.server(),
  };
}

class _InvalidResponse implements Exception {
  const _InvalidResponse();
}
