import 'package:bi_app/core/data/data_snapshot.dart';
import 'package:bi_app/core/data/load_status.dart';
import 'package:bi_app/core/error/failure.dart';
import 'package:bi_app/core/error/result.dart';
import 'package:bi_app/features/fx/domain/entities/conversion.dart';
import 'package:bi_app/features/fx/domain/entities/exchange_rates.dart';
import 'package:bi_app/features/fx/domain/repositories/fx_repository.dart';
import 'package:bi_app/features/fx/presentation/bloc/fx_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../fx_fixtures.dart';

class _MockRepository extends Mock implements FxRepository {}

void main() {
  late _MockRepository repository;

  setUp(() => repository = _MockRepository());

  FxCubit build() => FxCubit(repository: repository);

  void answer(Result<DataSnapshot<ExchangeRates>> result) =>
      when(() => repository.latest()).thenAnswer((_) async => result);

  final fresh = Success(DataSnapshot(data: rates, lastSyncedAt: fetchedAt));

  blocTest<FxCubit, FxState>(
    'carga tasas y convierte 100 USD → EUR',
    setUp: () => answer(fresh),
    build: build,
    act: (cubit) => cubit.load(),
    expect: () => [
      const FxState(rates: LoadState.loading()),
      FxState(
        rates: LoadState.success(rates),
        conversion: const Success(Conversion(amount: 92, rate: 0.92)),
      ),
    ],
  );

  blocTest<FxCubit, FxState>(
    'servicio caído con caché: estado stale con la hora de la caché',
    setUp: () => answer(
      Success(
        DataSnapshot(data: rates, isStale: true, lastSyncedAt: fetchedAt),
      ),
    ),
    build: build,
    act: (cubit) => cubit.load(),
    skip: 1,
    expect: () => [
      isA<FxState>()
          .having((s) => s.rates.status, 'status', LoadStatus.stale)
          .having((s) => s.rates.lastSyncedAt, 'lastSyncedAt', fetchedAt),
    ],
  );

  blocTest<FxCubit, FxState>(
    'servicio caído sin caché: failure; reintentar recupera',
    setUp: () => answer(const Err(Failure.server())),
    build: build,
    act: (cubit) async {
      await cubit.load();
      answer(fresh);
      await cubit.retry();
    },
    expect: () => [
      const FxState(rates: LoadState.loading()),
      const FxState(rates: LoadState.failure(Failure.server())),
      const FxState(rates: LoadState.loading()),
      isA<FxState>().having(
        (s) => s.rates.status,
        'status',
        LoadStatus.success,
      ),
    ],
  );

  blocTest<FxCubit, FxState>(
    'monto, divisas e intercambio recalculan la conversión',
    setUp: () => answer(fresh),
    build: build,
    act: (cubit) async {
      await cubit.load();
      cubit
        ..amountChanged('10,5')
        ..toChanged('JPY')
        ..swap()
        ..amountChanged('abc')
        ..amountChanged('');
    },
    skip: 2,
    expect: () => [
      isA<FxState>().having(
        (s) => s.conversion?.valueOrNull?.amount,
        '10,5 USD → EUR',
        9.66,
      ),
      isA<FxState>().having(
        (s) => s.conversion?.valueOrNull?.amount,
        '10,5 USD → JPY',
        1570.0,
      ),
      isA<FxState>()
          .having((s) => s.from, 'from', 'JPY')
          .having((s) => s.to, 'to', 'USD')
          .having(
            (s) => s.conversion?.valueOrNull?.amount,
            '10,5 JPY → USD',
            0.07,
          ),
      isA<FxState>().having(
        (s) => s.conversion,
        'monto inválido',
        const Err<Conversion>(Failure.validation('amount')),
      ),
      isA<FxState>().having((s) => s.conversion, 'monto vacío', isNull),
    ],
  );

  blocTest<FxCubit, FxState>(
    'una divisa que ya no se publica vuelve a una válida',
    setUp: () => answer(fresh),
    build: build,
    seed: () => const FxState(from: 'COP', to: 'PEN'),
    act: (cubit) => cubit.load(),
    skip: 1,
    expect: () => [
      isA<FxState>()
          .having((s) => s.from, 'from', 'USD')
          .having((s) => s.to, 'to', 'MXN'),
    ],
  );
}
