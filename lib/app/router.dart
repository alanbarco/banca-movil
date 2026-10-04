import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../core/modules/feature_module.dart';
import '../core/observability/app_logger.dart';
import '../core/routing/app_routes.dart';
import '../core/session/session_timeout_service.dart';
import 'not_found_page.dart';
import 'route_guard.dart';
import 'shell/app_shell.dart';
import 'splash_page.dart';

final _logger = AppLogger('router');

/// Compone las rutas de las features bajo `/splash` y el shell de pestañas.
GoRouter createRouter({
  required RouteGuard guard,
  required SessionTimeoutService sessionTimeout,
  required List<FeatureModule> modules,
  List<Stream<Object?>> refreshOn = const [],
  String? Function()? splashDebugInfo,
  String initialLocation = AppRoutes.splash,
}) {
  final shellRoutes = [for (final m in modules) ...m.shellRoutes];
  final destinations = AppShell.destinationsFor(shellRoutes);
  final refresh = StreamListenable(refreshOn);

  return GoRouter(
    initialLocation: initialLocation,
    refreshListenable: refresh,
    redirect: (context, state) {
      final target = guard.redirect(state.uri);
      _logger.debug('redirect', {
        'from': state.uri.path,
        'to': target ?? '(sin cambio)',
        'session': guard.sessionStatus.name,
      });
      return target;
    },
    errorBuilder: (context, state) => const NotFoundPage(),
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) =>
            SplashPage(debugInfo: kDebugMode ? splashDebugInfo?.call() : null),
      ),
      for (final module in modules) ...module.routes,
      if (shellRoutes.isNotEmpty)
        ShellRoute(
          builder: (context, state, child) => AppShell(
            location: state.uri.path,
            destinations: destinations,
            sessionTimeout: sessionTimeout,
            isTabEnabled: guard.isAllowedByFlags,
            // El router no reconstruye el shell si la ruta no cambia.
            tabChanges: refresh,
            child: child,
          ),
          routes: shellRoutes,
        ),
    ],
  );
}

/// Re-evalúa el `redirect` cuando cambia la sesión o los flags.
class StreamListenable extends ChangeNotifier {
  StreamListenable(List<Stream<Object?>> streams) {
    for (final stream in streams) {
      _subscriptions.add(stream.listen((_) => notifyListeners()));
    }
  }

  final List<StreamSubscription<Object?>> _subscriptions = [];

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    super.dispose();
  }
}
