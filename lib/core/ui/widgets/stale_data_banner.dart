import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme.dart';

/// Aviso de datos desde caché (estado `stale`, FR-028).
class StaleDataBanner extends StatelessWidget {
  const StaleDataBanner({this.lastSyncedAt, super.key});

  final DateTime? lastSyncedAt;

  static String messageFor(DateTime? lastSyncedAt) {
    if (lastSyncedAt == null) return 'Sin conexión · mostrando datos guardados';
    final time = DateFormat('HH:mm').format(lastSyncedAt.toLocal());
    return 'Sin conexión · actualizado a las $time';
  }

  @override
  Widget build(BuildContext context) {
    final message = messageFor(lastSyncedAt);
    return Semantics(
      container: true,
      liveRegion: true,
      label: message,
      excludeSemantics: true,
      child: Container(
        width: double.infinity,
        color: AppColors.warningContainer,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.spacing,
          vertical: 8,
        ),
        child: Row(
          children: [
            const Icon(
              Icons.history,
              size: 18,
              color: AppColors.onWarningContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.onWarningContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
