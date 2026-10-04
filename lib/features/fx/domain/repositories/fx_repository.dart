import '../../../../core/data/data_snapshot.dart';
import '../../../../core/error/result.dart';
import '../entities/exchange_rates.dart';

/// Tipos de cambio del servicio externo (FR-019, FR-021, FR-022).
abstract interface class FxRepository {
  /// Pide las tasas vigentes. Si el servicio falla y hay caché, la devuelve
  /// con `isStale`; si no hay caché, `Err`.
  Future<Result<DataSnapshot<ExchangeRates>>> latest();
}
