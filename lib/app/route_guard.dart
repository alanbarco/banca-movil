import '../core/flags/feature_flag_service.dart';
import '../core/flags/flag_keys.dart';
import '../core/routing/app_routes.dart';
import '../core/session/session_status.dart';

/// Reglas de `redirect` de `contracts/ui-routes.md`, separadas de GoRouter
/// para poder probarlas sin widgets.
class RouteGuard {
  RouteGuard({
    required SessionStatusSource session,
    required FeatureFlagService flags,
    String? Function()? currentSegment,
    this.demoTools = false,
  }) : _session = session,
       _flags = flags,
       _currentSegment = currentSegment;

  final SessionStatusSource _session;
  final FeatureFlagService _flags;
  final String? Function()? _currentSegment;
  final bool demoTools;

  SessionStatus get sessionStatus => _session.status;

  /// Ruta a la que hay que ir, o `null` para quedarse en [uri].
  String? redirect(Uri uri) {
    final path = uri.path;
    switch (_session.status) {
      case SessionStatus.unknown:
        return path == AppRoutes.splash ? null : AppRoutes.splash;

      case SessionStatus.unauthenticated:
        if (path != AppRoutes.splash && AppRoutes.isPublic(path)) return null;
        return AppRoutes.login;

      case SessionStatus.needsOnboarding:
        return path == AppRoutes.register ? null : AppRoutes.register;

      case SessionStatus.authenticated:
        // Tras login o registro el destino es siempre el inicio.
        if (AppRoutes.isPublic(path)) return AppRoutes.home;
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
