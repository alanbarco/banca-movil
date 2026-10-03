import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/ui/theme.dart';
import '../auth_texts.dart';
import '../bloc/auth_bloc.dart';

/// Datos del cliente y cierre de sesión. Las secciones de intereses y
/// notificaciones se completan en US3 y US5.
class ProfilePage extends StatelessWidget {
  const ProfilePage({required this.authBloc, super.key});

  final AuthBloc authBloc;

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
                    Text('Intereses', style: theme.textTheme.titleMedium),
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
}
