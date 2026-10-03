import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/ui/balance_visibility_cubit.dart';
import '../accounts_texts.dart';

/// Alterna "ocultar saldos" (FR-010); la preferencia persiste.
class BalanceVisibilityButton extends StatelessWidget {
  const BalanceVisibilityButton({super.key});

  @override
  Widget build(BuildContext context) {
    final hidden = context.select<BalanceVisibilityCubit, bool>((c) => c.state);
    return IconButton(
      onPressed: () => context.read<BalanceVisibilityCubit>().toggle(),
      tooltip: hidden ? AccountsTexts.showBalances : AccountsTexts.hideBalances,
      icon: Icon(
        hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
      ),
    );
  }
}
