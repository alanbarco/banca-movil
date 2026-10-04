import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/ui/theme.dart';
import '../../domain/entities/interest.dart';
import '../../domain/usecases/update_interests.dart';
import '../auth_texts.dart';
import '../bloc/auth_bloc.dart';
import '../widgets/edit_interests_sheet.dart';

/// Datos del cliente, intereses editables (FR-018) y cierre de sesión. La
/// sección de notificaciones se completa en US5.
class ProfilePage extends StatelessWidget {
  const ProfilePage({
    required this.authBloc,
    required this.updateInterests,
    super.key,
  });

  final AuthBloc authBloc;
  final UpdateInterests updateInterests;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mi perfil')),
      body: BlocBuilder<AuthBloc, AuthState>(
        bloc: authBloc,
        builder: (context, state) {
          final profile = state.profile;
          if (profile == null) return const SizedBox.shrink();
          final theme = Theme.of(context);
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: AppSizes.spacing),
            children: [
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('Nombre'),
                subtitle: Text(profile.fullName),
              ),
              ListTile(
                leading: const Icon(Icons.email_outlined),
                title: const Text('Correo'),
                subtitle: Text(profile.email),
              ),
              ListTile(
                leading: Icon(profile.segment.icon),
                title: const Text('Perfil'),
                subtitle: Text(profile.segment.label),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.spacing,
                  8,
                  AppSizes.spacing,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Intereses',
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () =>
                              _editInterests(context, profile.interests),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Editar'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final interest in profile.interests)
                          Chip(
                            avatar: Icon(interest.icon, size: 18),
                            label: Text(interest.label),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: AppSizes.spacing * 3),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.spacing,
                ),
                child: OutlinedButton.icon(
                  onPressed: () => authBloc.add(const LogoutRequested()),
                  icon: const Icon(Icons.logout),
                  label: const Text('Cerrar sesión'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _editInterests(
    BuildContext context,
    List<Interest> current,
  ) async {
    final saved = await EditInterestsSheet.show(
      context,
      initial: current,
      onSave: updateInterests.call,
    );
    if (saved != true || !context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Intereses actualizados.')));
  }
}
