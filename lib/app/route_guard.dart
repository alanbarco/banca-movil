import '../core/flags/feature_flag_service.dart';
import '../core/flags/flag_keys.dart';
import '../core/routing/app_routes.dart';
import '../core/routing/pending_route_store.dart';
import '../core/session/session_status.dart';

/// Reglas de `redirect` de `contracts/ui-routes.md`, separadas de GoRouter
/// para poder probarlas sin widgets.
class RouteGuard {
  RouteGuard({
    required SessionStatusSource session,
    required FeatureFlagService flags,
    required PendingRouteStore pendingRoutes,
    String? Function()? currentSegment,
    this.demoTools = false,
  }) : _session = session,
       _flags = flags,
       _pending = pendingRoutes,
       _currentSegment = currentSegment;

  final SessionStatusSource _session;
  final FeatureFlagService _flags;
  final PendingRouteStore _pending;
  final String? Function()? _currentSegment;
  final bool demoTools;

  /// Ruta a la que hay que ir, o `null` para quedarse en [uri].
  String? redirect(Uri uri) {
    final path = uri.path;
    switch (_session.status) {
      case SessionStatus.unknown:
        if (path == AppRoutes.splash) return null;
        _pending.save(uri.toString());
        return AppRoutes.splash;

      case SessionStatus.unauthenticated:
        if (path != AppRoutes.splash && AppRoutes.isPublic(path)) return null;
        _pending.save(uri.toString());
        return AppRoutes.login;

      case SessionStatus.needsOnboarding:
        return path == AppRoutes.register ? null : AppRoutes.register;

      case SessionStatus.authenticated:
        if (AppRoutes.isPublic(path)) return _pending.take() ?? AppRoutes.home;
        return isAllowedByFlags(path) ? null : AppRoutes.home;
    }
  }

  /// Rutas con flag apagado no son accesibles (ni por deep link).
  bool isAllowedByFlags(String path) {
    final segment = _currentSegment?.call();
    bool enabled(String key) => _flags.isEnabled(key, segment: segment);

    if (path == AppRoutes.fx) return enabled(FlagKeys.fxService);
    if (path.startsWith('/offers/')) return enabled(FlagKeys.offers);
    if (path == AppRoutes.debugFaults) {
      return demoTools && enabled(FlagKeys.demoFaultPanel);
    }
    return true;
  }
}
