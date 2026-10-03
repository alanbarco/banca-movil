import 'package:flutter/material.dart';

import '../../../../core/sdui/home_section.dart';
import '../../../../core/sdui/section_registry.dart';
import '../../../../core/session/current_user_profile.dart';
import '../../../../core/ui/theme.dart';

/// Inicio interino de US2: saludo y la sección `accounts_summary` dibujada
/// vía [SectionRegistry]. US3 lo reemplaza por el inicio SDUI completo
/// (T089).
class HomePage extends StatelessWidget {
  const HomePage({
    required this.currentUser,
    required this.sections,
    super.key,
  });

  final CurrentUserProfile currentUser;
  final SectionRegistry sections;

  static const accountsSummary = HomeSection(
    id: 'accounts_summary',
    type: HomeSectionType.accountsSummary,
    order: 0,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inicio')),
      body: StreamBuilder<SessionUser?>(
        stream: currentUser.user,
        initialData: currentUser.current,
        builder: (context, snapshot) {
          final user = snapshot.data;
          return ListView(
            padding: const EdgeInsets.all(AppSizes.spacing),
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
              const SizedBox(height: AppSizes.spacing * 1.5),
              ?sections.build(context, accountsSummary),
            ],
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
