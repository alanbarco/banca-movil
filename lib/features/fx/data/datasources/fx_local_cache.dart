import '../../../../core/storage/local_storage.dart';
import '../../domain/entities/exchange_rates.dart';
import '../models/exchange_rates_model.dart';

/// Última respuesta válida del servicio de tipos de cambio (FR-021).
/// Las tasas son públicas, por eso viven en `shared_preferences`.
class FxLocalCache {
  const FxLocalCache(this._storage);

  static const key = 'fx_last_rates';

  final LocalStorage _storage;

  ExchangeRates? read({required String expectedBase}) {
    final json = _storage.getJson(key);
    if (json == null) return null;
    return ExchangeRatesModel.fromCache(json, expectedBase: expectedBase);
  }

  Future<void> write(ExchangeRates rates) =>
      _storage.setJson(key, ExchangeRatesModel.toCache(rates));
}
