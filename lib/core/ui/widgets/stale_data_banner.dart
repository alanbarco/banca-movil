import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme.dart';

/// Aviso de datos desde caché (estado `stale`, FR-028).
class StaleDataBanner extends StatelessWidget {
  const StaleDataBanner({
    this.lastSyncedAt,
    this.cause = defaultCause,
    super.key,
  });

  static const defaultCause = 'Sin conexión';

  final DateTime? lastSyncedAt;

  /// Por qué no hay datos frescos (p. ej. un servicio externo caído).
  final String cause;

  static String messageFor(
    DateTime? lastSyncedAt, {
    String cause = defaultCause,
  }) {
    if (lastSyncedAt == null) return '$cause · mostrando datos guardados';
    final time = DateFormat('HH:mm').format(lastSyncedAt.toLocal());
    return '$cause · actualizado a las $time';
  }

  @override
  Widget build(BuildContext context) {
    final message = messageFor(lastSyncedAt, cause: cause);
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
