import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/fault_injection/fault_panel_access.dart';
import '../../../../core/notifications/notifications_toggle.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/ui/theme.dart';
import '../../domain/entities/interest.dart';
import '../../domain/usecases/update_interests.dart';
import '../auth_texts.dart';
import '../bloc/auth_bloc.dart';
import '../widgets/edit_interests_sheet.dart';

/// Datos del cliente, intereses editables (FR-018), notificaciones (FR-023)
/// y cierre de sesión.
class ProfilePage extends StatelessWidget {
  const ProfilePage({
    required this.authBloc,
    required this.updateInterests,
    this.notifications,
    this.faultPanel,
    super.key,
  });

  final AuthBloc authBloc;
  final UpdateInterests updateInterests;

  /// `null` si la feature de notificaciones no está registrada.
  final NotificationsToggle? notifications;

  /// Acceso al simulador de fallos (solo builds de demo con el flag).
  final FaultPanelAccess? faultPanel;

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
              if (notifications case final toggle?) ...[
                const Divider(height: AppSizes.spacing * 3),
                _NotificationsTile(
                  enabled: profile.notificationsEnabled,
                  toggle: toggle,
                ),
              ],
              if (faultPanel?.isAllowed ?? false)
                ListTile(
                  leading: const Icon(Icons.bug_report_outlined),
                  title: const Text('Simulador de fallos'),
                  subtitle: const Text('Demo: sin red, latencia o error'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.debugFaults),
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

class _NotificationsTile extends StatefulWidget {
  const _NotificationsTile({required this.enabled, required this.toggle});

  final bool enabled;
  final NotificationsToggle toggle;

  static const deniedMessage =
      'Las notificaciones están bloqueadas. Actívalas desde los ajustes '
      'del teléfono.';

  @override
  State<_NotificationsTile> createState() => _NotificationsTileState();
}

class _NotificationsTileState extends State<_NotificationsTile> {
  bool _saving = false;

  Future<void> _change(bool enabled) async {
    setState(() => _saving = true);
    final applied = await widget.toggle.setEnabled(enabled: enabled);
    if (!mounted) return;
    setState(() => _saving = false);
    if (!applied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(_NotificationsTile.deniedMessage)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: const Icon(Icons.notifications_outlined),
      title: const Text('Notificaciones'),
      subtitle: const Text('Movimientos de tus cuentas y ofertas para ti'),
      value: widget.enabled,
      onChanged: _saving ? null : _change,
    );
  }
}
