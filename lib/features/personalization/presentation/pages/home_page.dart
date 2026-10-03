import 'package:flutter/material.dart';

import '../../../../core/session/current_user_profile.dart';
import '../../../../core/ui/theme.dart';
import '../../../../core/ui/widgets/empty_view.dart';

/// Inicio interino de US1: confirma el acceso. US2 agrega el resumen de
/// cuentas (T080) y US3 lo reemplaza por el inicio SDUI completo (T089).
class HomePage extends StatelessWidget {
  const HomePage({required this.currentUser, super.key});

  final CurrentUserProfile currentUser;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inicio')),
      body: StreamBuilder<SessionUser?>(
        stream: currentUser.user,
        initialData: currentUser.current,
        builder: (context, snapshot) {
          final user = snapshot.data;
          return Padding(
            padding: const EdgeInsets.all(AppSizes.spacing),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    'Bienvenido a BI App',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                if (user != null) ...[
                  const SizedBox(height: 8),
                  Text('Perfil: ${_segmentLabel(user.segment)}'),
                ],
                const Expanded(
                  child: EmptyView(
                    message:
                        'Tu cuenta ya está abierta. Muy pronto verás '
                        'aquí tus saldos y movimientos.',
                    icon: Icons.account_balance_outlined,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// `segment` llega con el valor de Firestore; esta feature no depende de
  /// `auth`, así que la etiqueta se traduce aquí.
  static String _segmentLabel(String segment) => switch (segment) {
    'student' => 'Joven / estudiante',
    'professional' => 'Profesional',
    'entrepreneur' => 'Emprendedor',
    _ => segment,
  };
}
