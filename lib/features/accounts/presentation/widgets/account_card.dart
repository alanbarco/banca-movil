import 'package:flutter/material.dart';

import '../../../../core/ui/theme.dart';
import '../../../../core/ui/widgets/money_text.dart';
import '../../domain/entities/account.dart';
import '../accounts_texts.dart';

/// Tipo, número enmascarado y saldo; se anuncia como un solo elemento.
class AccountCard extends StatelessWidget {
  const AccountCard({required this.account, this.onTap, super.key});

  final Account account;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: MergeSemantics(
        child: Semantics(
          button: onTap != null,
          hint: onTap != null ? 'Ver movimientos' : null,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(AppSizes.spacing),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AccountsTexts.typeLabel(account.type),
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
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
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (onTap != null)
                    const ExcludeSemantics(child: Icon(Icons.chevron_right)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
