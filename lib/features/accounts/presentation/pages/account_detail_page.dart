import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/data/load_status.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/ui/theme.dart';
import '../../../../core/ui/widgets/empty_view.dart';
import '../../../../core/ui/widgets/error_view.dart';
import '../../../../core/ui/widgets/money_text.dart';
import '../../../../core/ui/widgets/skeleton.dart';
import '../../../../core/ui/widgets/stale_data_banner.dart';
import '../../domain/entities/account.dart';
import '../../domain/entities/movement.dart';
import '../accounts_texts.dart';
import '../bloc/account_detail_cubit.dart';
import '../bloc/movements_bloc.dart';
import '../widgets/balance_visibility_button.dart';
import '../widgets/movement_tile.dart';

/// Saldo y movimientos de una cuenta, en vivo y paginados (FR-011, FR-012).
/// Requiere un [AccountDetailCubit] y un [MovementsBloc].
class AccountDetailPage extends StatelessWidget {
  const AccountDetailPage({super.key});

  /// Distancia al final de la lista a la que se pide la página siguiente.
  static const loadMoreThreshold = 300.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AccountsTexts.movementsTitle),
        actions: const [BalanceVisibilityButton()],
      ),
      body: BlocBuilder<AccountDetailCubit, LoadState<Account>>(
        builder: (context, account) {
          final failure = account.failure;
          if (account.status == LoadStatus.failure && failure != null) {
            return ErrorView(
              message: AccountsTexts.loadError(failure),
              onRetry: AccountsTexts.isRetryable(failure)
                  ? () => _retryAll(context)
                  : null,
            );
          }
          return BlocBuilder<MovementsBloc, MovementsState>(
            builder: (context, movements) =>
                _MovementsList(account: account, movements: movements),
          );
        },
      ),
    );
  }

  static void _retryAll(BuildContext context) {
    context.read<AccountDetailCubit>().retry();
    context.read<MovementsBloc>().add(const MovementsRetried());
  }
}

class _MovementsList extends StatelessWidget {
  const _MovementsList({required this.account, required this.movements});

  final LoadState<Account> account;
  final MovementsState movements;

  /// Hora de sincronización más antigua entre saldo y movimientos.
  DateTime? get _staleSince {
    final times = [
      if (account.status == LoadStatus.stale) account.lastSyncedAt,
      if (movements.status == LoadStatus.stale) movements.lastSyncedAt,
    ].nonNulls.toList()..sort();
    return times.isEmpty ? null : times.first;
  }

  bool get _isStale =>
      account.status == LoadStatus.stale ||
      movements.status == LoadStatus.stale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = account.data;
    final top = <Widget>[
      if (_isStale) StaleDataBanner(lastSyncedAt: _staleSince),
      Padding(
        padding: const EdgeInsets.all(AppSizes.spacing),
        child: data == null
            ? Semantics(
                label: AccountsTexts.loadingAccounts,
                child: const Skeleton(height: 112, radius: AppSizes.radius),
              )
            : _AccountHeader(account: data),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.spacing,
          0,
          AppSizes.spacing,
          8,
        ),
        child: Semantics(
          header: true,
          child: Text(
            AccountsTexts.movementsTitle,
            style: theme.textTheme.titleLarge,
          ),
        ),
      ),
    ];

    final items = movements.hasData ? movements.items : const <Movement>[];
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.extentAfter <
                AccountDetailPage.loadMoreThreshold &&
            movements.hasMore &&
            !movements.loadingMore &&
            movements.loadMoreFailure == null) {
          context.read<MovementsBloc>().add(const MovementsLoadMoreRequested());
        }
        return false;
      },
      child: ListView.builder(
        itemCount: top.length + items.length + 1,
        itemBuilder: (context, index) {
          if (index < top.length) return top[index];
          final i = index - top.length;
          if (i < items.length) return MovementTile(movement: items[i]);
          return _footer(context);
        },
      ),
    );
  }

  Widget _footer(BuildContext context) {
    switch (movements.status) {
      case LoadStatus.initial:
      case LoadStatus.loading:
        return const SkeletonList(
          itemCount: 5,
          semanticsLabel: AccountsTexts.loadingMovements,
        );
      case LoadStatus.empty:
        return const EmptyView(
          message: AccountsTexts.noMovements,
          icon: Icons.receipt_long_outlined,
        );
      case LoadStatus.failure:
        final failure = movements.failure ?? const Failure.unknown();
        return ErrorView(
          message: AccountsTexts.loadError(failure),
          onRetry: () =>
              context.read<MovementsBloc>().add(const MovementsRetried()),
        );
      case LoadStatus.success:
      case LoadStatus.stale:
        return Padding(
          padding: const EdgeInsets.all(AppSizes.spacing),
          child: _pagination(context),
        );
    }
  }

  Widget _pagination(BuildContext context) {
    void loadMore() =>
        context.read<MovementsBloc>().add(const MovementsLoadMoreRequested());

    if (movements.loadingMore) {
      return const Center(
        child: CircularProgressIndicator(
          semanticsLabel: AccountsTexts.loadingMore,
        ),
      );
    }
    if (movements.loadMoreFailure != null) {
      return Column(
        children: [
          Semantics(
            liveRegion: true,
            child: const Text(
              AccountsTexts.loadMoreFailed,
              textAlign: TextAlign.center,
            ),
          ),
          TextButton.icon(
            onPressed: loadMore,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      );
    }
    if (movements.hasMore) {
      // Además del scroll automático: accesible con lector de pantalla.
      return TextButton(
        onPressed: loadMore,
        child: const Text(AccountsTexts.loadMore),
      );
    }
    return Text(
      AccountsTexts.endOfList,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodySmall,
    );
  }
}

class _AccountHeader extends StatelessWidget {
  const _AccountHeader({required this.account});

  final Account account;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: MergeSemantics(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.spacing),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AccountsTexts.typeLabel(account.type),
                style: theme.textTheme.titleMedium,
              ),
              Semantics(
                label: AccountsTexts.maskedNumberLabel(account),
                excludeSemantics: true,
                child: Text(
                  account.maskedNumber,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                AccountsTexts.availableBalance,
                style: theme.textTheme.labelMedium,
              ),
              MoneyText(
                account.balanceCents,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
