import 'package:flutter/material.dart';

import '../../../../core/ui/theme.dart';
import '../../../../core/ui/widgets/money_text.dart';
import '../../domain/entities/movement.dart';
import '../accounts_texts.dart';

/// Ingreso o egreso: se distingue por ícono, texto y signo, no solo por color
/// (FR-033).
class MovementTile extends StatelessWidget {
  const MovementTile({required this.movement, super.key});

  final Movement movement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCredit = movement.isCredit;
    final color = isCredit ? AppColors.credit : AppColors.debit;
    final kind = isCredit ? AccountsTexts.credit : AccountsTexts.debit;
    return MergeSemantics(
      child: ListTile(
        leading: ExcludeSemantics(
          child: CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.12),
            foregroundColor: color,
            child: Icon(isCredit ? Icons.south_west : Icons.north_east),
          ),
        ),
        title: Text(
          movement.description,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text('$kind · ${AccountsTexts.date(movement.date)}'),
        trailing: MoneyText(
          movement.signedAmountCents,
          showSign: true,
          style: theme.textTheme.titleMedium?.copyWith(color: color),
        ),
      ),
    );
  }
}
