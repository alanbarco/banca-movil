import 'package:flutter/material.dart';

import '../../../../core/sdui/home_section.dart';
import '../../../../core/ui/theme.dart';
import '../sdui_navigation.dart';

/// Sección `quick_actions`. Las acciones con `flag` apagado ya llegan
/// filtradas desde `ResolveHomeLayout`.
class QuickActionsSection extends StatelessWidget {
  const QuickActionsSection({required this.section, super.key});

  static const title = 'Accesos rápidos';

  /// Íconos que el banco puede usar por nombre; uno desconocido usa
  /// [fallbackIcon] en lugar de omitir la acción.
  static const icons = <String, IconData>{
    'currency_exchange': Icons.currency_exchange,
    'person': Icons.person_outline,
    'home': Icons.home_outlined,
    'savings': Icons.savings_outlined,
    'account_balance': Icons.account_balance_outlined,
    'local_offer': Icons.local_offer_outlined,
    'notifications': Icons.notifications_outlined,
    'trending_up': Icons.trending_up,
  };
  static const fallbackIcon = Icons.apps;

  final HomeSection section;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = (section.payload['items'] as List)
        .whereType<Map<String, dynamic>>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(title, style: theme.textTheme.titleLarge),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final item in items)
              FilledButton.tonalIcon(
                onPressed: () =>
                    openSduiRoute(context, item['route'] as String),
                icon: Icon(icons[item['icon']] ?? fallbackIcon),
                label: Text(item['label'] as String),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, AppSizes.minTouchTarget),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
