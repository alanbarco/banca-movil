import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/sdui/section_registry.dart';
import '../../../../core/ui/theme.dart';
import '../../../../core/ui/widgets/empty_view.dart';
import '../../../../core/ui/widgets/skeleton.dart';
import '../bloc/home_layout_cubit.dart';

/// Inicio SDUI: secciones definidas por el banco y dibujadas vía
/// [SectionRegistry] (FR-014). Requiere un [HomeLayoutCubit].
class HomePage extends StatelessWidget {
  const HomePage({required this.sections, super.key});

  final SectionRegistry sections;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inicio')),
      body: BlocBuilder<HomeLayoutCubit, HomeLayoutState>(
        builder: (context, state) {
          if (state.loading) {
            return const SkeletonList(
              itemHeight: 112,
              semanticsLabel: 'Cargando tu inicio',
            );
          }
          final segment = state.segment;
          return RefreshIndicator(
            onRefresh: context.read<HomeLayoutCubit>().refresh,
            child: ListView(
              // Pull-to-refresh también con poco contenido.
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSizes.spacing),
              children: [
                if (segment != null) ...[
                  Text(
                    'Perfil: ${segmentLabel(segment)}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSizes.spacing),
                ],
                if (state.sections.isEmpty)
                  const EmptyView(
                    message: 'Tu inicio no tiene contenido por ahora.',
                  ),
                for (final section in state.sections)
                  Padding(
                    // La clave conserva el estado de cada sección (p. ej. el
                    // cubit de cuentas) aunque el banco las reordene.
                    key: ValueKey(section.id),
                    padding: const EdgeInsets.only(
                      bottom: AppSizes.spacing * 1.5,
                    ),
                    child:
                        sections.build(context, section) ??
                        const SizedBox.shrink(),
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
  static String segmentLabel(String segment) => switch (segment) {
    'student' => 'Joven / estudiante',
    'professional' => 'Profesional',
    'entrepreneur' => 'Emprendedor',
    _ => segment,
  };
}
