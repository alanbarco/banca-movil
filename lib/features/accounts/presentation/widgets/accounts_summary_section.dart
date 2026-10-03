import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/data/load_status.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/ui/theme.dart';
import '../../../../core/ui/widgets/empty_view.dart';
import '../../../../core/ui/widgets/error_view.dart';
import '../../../../core/ui/widgets/skeleton.dart';
import '../../../../core/ui/widgets/stale_data_banner.dart';
import '../../domain/entities/account.dart';
import '../accounts_texts.dart';
import '../bloc/accounts_cubit.dart';
import 'account_card.dart';
import 'balance_visibility_button.dart';

/// Sección SDUI `accounts_summary`: cuentas del cliente y "ocultar saldos".
/// Requiere un [AccountsCubit].
class AccountsSummarySection extends StatelessWidget {
  const AccountsSummarySection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AccountsCubit, LoadState<List<Account>>>(
      builder: (context, state) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    AccountsTexts.accountsTitle,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ),
              const BalanceVisibilityButton(),
            ],
          ),
          const SizedBox(height: 8),
          ..._body(context, state),
        ],
      ),
    );
  }

  List<Widget> _body(BuildContext context, LoadState<List<Account>> state) {
    final accounts = state.data;
    switch (state.status) {
      case LoadStatus.initial:
      case LoadStatus.loading:
        if (accounts != null) return _cards(context, accounts);
        return [
          Semantics(
            label: AccountsTexts.loadingAccounts,
            liveRegion: true,
            child: const Skeleton(height: 132, radius: AppSizes.radius),
          ),
        ];
      case LoadStatus.success:
        return _cards(context, accounts ?? const []);
      case LoadStatus.stale:
        return [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSizes.radius),
            child: StaleDataBanner(lastSyncedAt: state.lastSyncedAt),
          ),
          const SizedBox(height: 12),
          ..._cards(context, accounts ?? const []),
        ];
      case LoadStatus.empty:
        return const [
          EmptyView(
            message: AccountsTexts.noAccounts,
            icon: Icons.account_balance_outlined,
          ),
        ];
      case LoadStatus.failure:
        final failure = state.failure!;
        return [
          ErrorView(
            message: AccountsTexts.loadError(failure),
            onRetry: AccountsTexts.isRetryable(failure)
                ? context.read<AccountsCubit>().retry
                : null,
          ),
        ];
    }
  }

  List<Widget> _cards(BuildContext context, List<Account> accounts) => [
    for (final account in accounts)
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: AccountCard(
          account: account,
          onTap: () => context.push(AppRoutes.account(account.id)),
        ),
      ),
  ];
}
