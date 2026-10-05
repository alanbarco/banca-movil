import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/push_message.dart';
import '../bloc/notifications_cubit.dart';
import '../push_route_opener.dart';
import 'permission_explainer_dialog.dart';

/// Envuelve el shell: muestra las push que llegan con la app abierta como
/// `MaterialBanner` (sin interrumpir, FR-025) y la explicación del permiso
/// la primera vez. Requiere un [NotificationsCubit].
class InAppNotificationListener extends StatelessWidget {
  const InAppNotificationListener({required this.child, super.key});

  static const view = 'Ver';
  static const close = 'Cerrar';

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocListener<NotificationsCubit, NotificationsState>(
      listener: (context, state) async {
        final messenger = ScaffoldMessenger.of(context)
          ..hideCurrentMaterialBanner();
        final message = state.inApp;
        if (message != null) {
          messenger.showMaterialBanner(_banner(context, message));
        }
        if (state.showExplainer) await _explain(context);
      },
      child: child,
    );
  }

  MaterialBanner _banner(BuildContext context, PushMessage message) {
    final cubit = context.read<NotificationsCubit>();
    final theme = Theme.of(context);
    return MaterialBanner(
      leading: const Icon(Icons.notifications_outlined),
      content: Semantics(
        liveRegion: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.title.isNotEmpty)
              Text(message.title, style: theme.textTheme.titleSmall),
            if (message.body.isNotEmpty) Text(message.body),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: cubit.dismiss, child: const Text(close)),
        TextButton(
          onPressed: () {
            final route = cubit.open(message);
            if (route != null) openPushRoute(GoRouter.of(context), route);
          },
          child: const Text(view),
        ),
      ],
    );
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
