import '../../domain/entities/exchange_rates.dart';

/// JSON de Frankfurter (`{base, date, rates}`) y de la caché local (que
/// además guarda `fetchedAt`).
abstract final class ExchangeRatesModel {
  /// `null` si la respuesta no cumple el contrato: base distinta de
  /// [expectedBase], fecha ilegible o sin tasas válidas.
  static ExchangeRates? fromJson(
    Map<String, dynamic> json, {
    required String expectedBase,
    required DateTime fetchedAt,
  }) {
    final base = json['base'];
    final date = json['date'];
    final rawRates = json['rates'];
    if (base != expectedBase || date is! String || rawRates is! Map) {
      return null;
    }
    final parsedDate = DateTime.tryParse(date);
    if (parsedDate == null) return null;

    final rates = <String, double>{
      for (final entry in rawRates.entries)
        if (entry.key is String && entry.value is num && entry.value as num > 0)
          entry.key as String: (entry.value as num).toDouble(),
    };
    if (rates.isEmpty) return null;

    return ExchangeRates(
      base: base as String,
      date: parsedDate,
      rates: rates,
      fetchedAt: fetchedAt,
    );
  }

  static ExchangeRates? fromCache(
    Map<String, dynamic> json, {
    required String expectedBase,
  }) {
    final fetchedAt = DateTime.tryParse('${json['fetchedAt']}');
    if (fetchedAt == null) return null;
    return fromJson(json, expectedBase: expectedBase, fetchedAt: fetchedAt);
  }

  static Map<String, dynamic> toCache(ExchangeRates rates) => {
    'base': rates.base,
    'date': _dateOnly(rates.date),
    'rates': rates.rates,
    'fetchedAt': rates.fetchedAt.toUtc().toIso8601String(),
  };

  static String _dateOnly(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
