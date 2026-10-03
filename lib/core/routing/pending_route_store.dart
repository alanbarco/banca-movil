import 'app_routes.dart';

/// Ruta destino guardada mientras el cliente inicia sesión (deep link de
/// push o ruta protegida abierta sin sesión).
class PendingRouteStore {
  String? _route;

  String? get pending => _route;

  /// Ignora rutas desconocidas y las públicas (no tiene sentido volver a ellas).
  void save(String route) {
    if (AppRoutes.isKnown(route) && !AppRoutes.isPublic(route)) {
      _route = route;
    }
  }

  /// Devuelve la ruta pendiente y la olvida.
  String? take() {
    final route = _route;
    _route = null;
    return route;
  }

  void clear() => _route = null;
}
