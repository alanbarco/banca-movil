import 'package:flutter/material.dart';

import '../core/ui/theme.dart';

/// Pantalla de arranque mientras se resuelve la sesión.
class SplashPage extends StatelessWidget {
  const SplashPage({this.debugInfo, super.key});

  /// Solo en debug: estado de la configuración para verificar el arranque.
  final String? debugInfo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.primary,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                header: true,
                child: Text(
                  'BI App',
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.spacing * 1.5),
              Semantics(
                label: 'Cargando',
                child: CircularProgressIndicator(
                  color: theme.colorScheme.onPrimary,
                ),
              ),
              if (debugInfo case final info?) ...[
                const SizedBox(height: AppSizes.spacing * 1.5),
                Text(
                  info,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
