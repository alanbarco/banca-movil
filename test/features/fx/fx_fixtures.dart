import 'package:bi_app/features/fx/domain/entities/exchange_rates.dart';

final fetchedAt = DateTime.utc(2026, 10, 4, 9, 30);

const frankfurterJson = <String, dynamic>{
  'amount': 1.0,
  'base': 'USD',
  'date': '2026-10-02',
  'rates': {'EUR': 0.92, 'JPY': 149.57, 'MXN': 18.4},
};

final rates = ExchangeRates(
  base: 'USD',
  date: DateTime(2026, 10, 2),
  rates: const {'EUR': 0.92, 'JPY': 149.57, 'MXN': 18.4},
  fetchedAt: fetchedAt,
);
