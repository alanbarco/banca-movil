import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/data/load_status.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/conversion.dart';
import '../../domain/entities/exchange_rates.dart';
import '../../domain/repositories/fx_repository.dart';
import '../../domain/usecases/convert_currency.dart';

class FxState extends Equatable {
  const FxState({
    this.rates = const LoadState.initial(),
    this.amountText = '100',
    this.from = ConvertCurrency.base,
    this.to = 'EUR',
    this.conversion,
  });

  final LoadState<ExchangeRates> rates;

  /// Lo que escribió el cliente (acepta coma o punto decimal).
  final String amountText;
  final String from;
  final String to;

  /// `null` mientras no haya tasas o el monto esté vacío.
  final Result<Conversion>? conversion;

  FxState copyWith({
    LoadState<ExchangeRates>? rates,
    String? amountText,
    String? from,
    String? to,
  }) => FxState(
    rates: rates ?? this.rates,
    amountText: amountText ?? this.amountText,
    from: from ?? this.from,
    to: to ?? this.to,
    conversion: conversion,
  );

  FxState withConversion(Result<Conversion>? conversion) => FxState(
    rates: rates,
    amountText: amountText,
    from: from,
    to: to,
    conversion: conversion,
  );

  @override
  List<Object?> get props => [rates, amountText, from, to, conversion];
}

/// Tasas del servicio externo y conversor (FR-019 a FR-022).
class FxCubit extends Cubit<FxState> {
  FxCubit({
    required FxRepository repository,
    ConvertCurrency convert = const ConvertCurrency(),
  }) : _repository = repository,
       _convert = convert,
       super(const FxState());

  final FxRepository _repository;
  final ConvertCurrency _convert;

  Future<void> load() async {
    if (state.rates.status == LoadStatus.loading) return;
    final previous = state.rates.data;
    emit(state.copyWith(rates: LoadState.loading(previous: previous)));

    final result = await _repository.latest();
    if (isClosed) return;
    final rates = result.fold<LoadState<ExchangeRates>>(
      (failure) => LoadState.failure(failure, previous: previous),
      (snapshot) => snapshot.isStale
          ? LoadState.stale(snapshot.data, lastSyncedAt: snapshot.lastSyncedAt)
          : LoadState.success(snapshot.data),
    );
    _update(state.copyWith(rates: rates));
  }

  Future<void> retry() => load();

  void amountChanged(String text) => _update(state.copyWith(amountText: text));

  void fromChanged(String currency) => _update(state.copyWith(from: currency));

  void toChanged(String currency) => _update(state.copyWith(to: currency));

  void swap() => _update(state.copyWith(from: state.to, to: state.from));

  /// Recalcula la conversión y corrige divisas que ya no se publican.
  void _update(FxState next) {
    final data = next.rates.data;
    if (data == null) {
      emit(next.withConversion(null));
      return;
    }
    final currencies = data.currencies;
    final fixed = next.copyWith(
      from: currencies.contains(next.from) ? next.from : data.base,
      to: currencies.contains(next.to) ? next.to : currencies.last,
    );
    emit(fixed.withConversion(_conversionFor(fixed, data)));
  }

  Result<Conversion>? _conversionFor(FxState state, ExchangeRates data) {
    final text = state.amountText.trim().replaceAll(',', '.');
    if (text.isEmpty) return null;
    final amount = double.tryParse(text);
    if (amount == null) return const Err(Failure.validation('amount'));
    return _convert(
      amount: amount,
      from: state.from,
      to: state.to,
      rates: data.rates,
    );
  }
}
