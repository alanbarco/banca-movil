import '../../../../core/routing/app_routes.dart';
import '../../../../core/routing/pending_route_store.dart';
import '../../../../core/session/session_status.dart';

/// Decide a dónde lleva una notificación tocada (FR-026).
///
/// Rutas desconocidas abren el inicio. Sin sesión, la ruta se guarda en
/// [PendingRouteStore] y se abre tras iniciar sesión.
class ResolvePushRoute {
  const ResolvePushRoute({
    required SessionStatusSource session,
    required PendingRouteStore pending,
  }) : _session = session,
       _pending = pending;

  final SessionStatusSource _session;
  final PendingRouteStore _pending;

  /// Ruta a abrir ahora, o `null` si quedó pendiente del login.
  String? call(String? route) {
    final target = route != null && AppRoutes.isKnown(route)
        ? route
        : AppRoutes.home;
    if (_session.status == SessionStatus.authenticated) return target;
    _pending.save(target);
    return null;
  }
}
