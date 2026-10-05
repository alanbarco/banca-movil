import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/push_message.dart';
import '../bloc/notifications_cubit.dart';
import '../push_route_opener.dart';
import 'permission_explainer_dialog.dart';

/// Envuelve el shell: muestra las push que llegan con la app abierta como una
/// tarjeta flotante arriba (se superpone, no desplaza el contenido; FR-025) y
/// la explicación del permiso la primera vez. Requiere un [NotificationsCubit].
///
/// El cubit decide qué aviso se ve y cuándo se cierra; este widget solo pone
/// o quita la tarjeta del `Overlay`.
class InAppNotificationListener extends StatefulWidget {
  const InAppNotificationListener({required this.child, super.key});

  static const view = 'Ver';
  static const close = 'Cerrar';

  final Widget child;

  @override
  State<InAppNotificationListener> createState() =>
      _InAppNotificationListenerState();
}

class _InAppNotificationListenerState extends State<InAppNotificationListener> {
  OverlayEntry? _entry;

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<NotificationsCubit, NotificationsState>(
          listenWhen: (previous, current) => previous.inApp != current.inApp,
          listener: (context, state) {
            _remove();
            final message = state.inApp;
            if (message != null) _show(context, message);
          },
        ),
        BlocListener<NotificationsCubit, NotificationsState>(
          listenWhen: (previous, current) =>
              !previous.showExplainer && current.showExplainer,
          listener: (context, _) => _explain(context),
        ),
      ],
      child: widget.child,
    );
  }

  void _show(BuildContext context, PushMessage message) {
    final cubit = context.read<NotificationsCubit>();
    final entry = OverlayEntry(
      builder: (_) => _TopNotification(
        message: message,
        onClose: cubit.dismiss,
        onView: () {
          final route = cubit.open(message);
          if (route != null && mounted) {
            openPushRoute(GoRouter.of(this.context), route);
          }
        },
      ),
    );
    Overlay.of(context).insert(entry);
    _entry = entry;
  }

  void _remove() {
    _entry
      ?..remove()
      ..dispose();
    _entry = null;
  }

  @override
  void dispose() {
    _remove();
    super.dispose();
  }

  static Future<void> _explain(BuildContext context) async {
    final cubit = context.read<NotificationsCubit>();
    final accepted = await PermissionExplainerDialog.show(context);
    if (accepted) {
      await cubit.acceptExplainer();
    } else {
      await cubit.declineExplainer();
    }
  }
}

/// Tarjeta arriba de la pantalla que entra deslizándose; se cierra con la ✕
/// o deslizándola hacia arriba.
class _TopNotification extends StatelessWidget {
  const _TopNotification({
    required this.message,
    required this.onClose,
    required this.onView,
  });

  final PushMessage message;
  final VoidCallback onClose;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: TweenAnimationBuilder<Offset>(
            tween: Tween(begin: const Offset(0, -1.5), end: Offset.zero),
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            builder: (context, offset, child) =>
                FractionalTranslation(translation: offset, child: child),
            child: Dismissible(
              key: ValueKey(message),
              direction: DismissDirection.up,
              onDismissed: (_) => onClose(),
              child: Material(
                elevation: 6,
                color: colors.inverseSurface,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
                  child: Semantics(
                    liveRegion: true,
                    child: Row(
                      children: [
                        Icon(
                          Icons.notifications_outlined,
                          color: colors.onInverseSurface,
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: _texts(theme)),
                        TextButton(
                          onPressed: onView,
                          style: TextButton.styleFrom(
                            foregroundColor: colors.inversePrimary,
                          ),
                          child: const Text(InAppNotificationListener.view),
                        ),
                        IconButton(
                          tooltip: InAppNotificationListener.close,
                          onPressed: onClose,
                          color: colors.onInverseSurface,
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _texts(ThemeData theme) {
    final color = theme.colorScheme.onInverseSurface;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (message.title.isNotEmpty)
          Text(
            message.title,
            style: theme.textTheme.titleSmall?.copyWith(color: color),
          ),
        if (message.body.isNotEmpty)
          Text(
            message.body,
            style: theme.textTheme.bodyMedium?.copyWith(color: color),
          ),
      ],
    );
  }
}
