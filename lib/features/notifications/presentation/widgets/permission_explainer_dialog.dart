import 'package:flutter/material.dart';

/// Explica para qué se usarán las push antes del diálogo del sistema
/// (FR-023). Devuelve `true` si el cliente quiere activarlas.
class PermissionExplainerDialog extends StatelessWidget {
  const PermissionExplainerDialog({super.key});

  static const title = '¿Activamos tus notificaciones?';
  static const body =
      'Te avisaremos al instante de los movimientos de tus cuentas y de '
      'ofertas pensadas para ti. Puedes cambiarlo cuando quieras desde tu '
      'perfil.';
  static const accept = 'Activar';
  static const decline = 'Ahora no';

  static Future<bool> show(BuildContext context) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (_) => const PermissionExplainerDialog(),
    );
    return accepted ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.notifications_active_outlined),
      title: const Text(title),
      content: const Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text(decline),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text(accept),
        ),
      ],
    );
  }
}
