import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/data/load_status.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/ui/theme.dart';
import '../../../../core/ui/widgets/error_view.dart';
import '../../../../core/ui/widgets/skeleton.dart';
import '../../../../core/ui/widgets/stale_data_banner.dart';
import '../../domain/entities/exchange_rates.dart';
import '../bloc/fx_cubit.dart';
import '../fx_texts.dart';

/// Tipos de cambio con fecha y conversor (FR-019 a FR-022).
/// Requiere un [FxCubit].
class FxPage extends StatelessWidget {
  const FxPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(FxTexts.title)),
      body: BlocBuilder<FxCubit, FxState>(
        builder: (context, state) {
          final rates = state.rates;
          final data = rates.data;
          if (data == null) {
            final failure = rates.failure;
            if (rates.status == LoadStatus.failure && failure != null) {
              return ErrorView(
                message: FxTexts.loadError(failure),
                onRetry: context.read<FxCubit>().retry,
              );
            }
            return const SkeletonList(semanticsLabel: FxTexts.loading);
          }
          return RefreshIndicator(
            onRefresh: context.read<FxCubit>().retry,
            child: ListView(
              children: [
                if (rates.status == LoadStatus.stale)
                  StaleDataBanner(
                    lastSyncedAt: rates.lastSyncedAt,
                    cause: FxTexts.unavailableCause,
                  ),
                if (rates.status == LoadStatus.loading)
                  const LinearProgressIndicator(
                    semanticsLabel: FxTexts.loading,
                  ),
                Padding(
                  padding: const EdgeInsets.all(AppSizes.spacing),
                  child: _Converter(state: state, data: data),
                ),
                _RatesList(data: data),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Converter extends StatefulWidget {
  const _Converter({required this.state, required this.data});

  final FxState state;
  final ExchangeRates data;

  @override
  State<_Converter> createState() => _ConverterState();
}

class _ConverterState extends State<_Converter> {
  late final _amount = TextEditingController(text: widget.state.amountText);

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cubit = context.read<FxCubit>();
    final state = widget.state;
    final currencies = widget.data.currencies;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.spacing),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                FxTexts.converterTitle,
                style: theme.textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('fx_amount'),
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: InputDecoration(
                labelText: FxTexts.amountLabel,
                border: const OutlineInputBorder(),
                errorText:
                    state.conversion?.failureOrNull ==
                        const Failure.validation('amount')
                    ? FxTexts.invalidAmount
                    : null,
              ),
              onChanged: cubit.amountChanged,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _CurrencyPicker(
                    key: const Key('fx_from'),
                    label: FxTexts.fromLabel,
                    value: state.from,
                    currencies: currencies,
                    onChanged: cubit.fromChanged,
                  ),
                ),
                IconButton(
                  tooltip: FxTexts.swap,
                  icon: const Icon(Icons.swap_horiz),
                  onPressed: cubit.swap,
                ),
                Expanded(
                  child: _CurrencyPicker(
                    key: const Key('fx_to'),
                    label: FxTexts.toLabel,
                    value: state.to,
                    currencies: currencies,
                    onChanged: cubit.toChanged,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (state.conversion case Success(:final value))
              Semantics(
                liveRegion: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      FxTexts.amount(value.amount, state.to),
                      key: const Key('fx_result'),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      FxTexts.rateUsed(value.rate, state.from, state.to),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CurrencyPicker extends StatelessWidget {
  const _CurrencyPicker({
    required this.label,
    required this.value,
    required this.currencies,
    required this.onChanged,
    super.key,
  });

  final String label;
  final String value;
  final List<String> currencies;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          items: [
            for (final currency in currencies)
              DropdownMenuItem(value: currency, child: Text(currency)),
          ],
          onChanged: (currency) {
            if (currency != null) onChanged(currency);
          },
        ),
      ),
    );
  }
}

class _RatesList extends StatelessWidget {
  const _RatesList({required this.data});

  final ExchangeRates data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final codes = data.rates.keys.toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.spacing),
          child: Semantics(
            header: true,
            child: Text(FxTexts.ratesTitle, style: theme.textTheme.titleLarge),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.spacing,
            4,
            AppSizes.spacing,
            8,
          ),
          child: Text(
            '${FxTexts.ratesDate(data.date)} · 1 ${data.base}',
            style: theme.textTheme.bodySmall,
          ),
        ),
        for (final code in codes)
          ListTile(
            title: Text(code),
            trailing: Text(
              FxTexts.rate(data.rates[code]!),
              style: theme.textTheme.titleMedium,
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(AppSizes.spacing),
          child: Text(FxTexts.source, style: theme.textTheme.bodySmall),
        ),
      ],
    );
  }
}
