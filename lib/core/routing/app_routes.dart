/// Rutas de `contracts/ui-routes.md`.
abstract final class AppRoutes {
  static const splash = '/splash';
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';
  static const home = '/home';
  static const accountDetail = '/accounts/:accountId';
  static const offerDetail = '/offers/:offerId';
  static const fx = '/fx';
  static const profile = '/profile';
  static const debugFaults = '/debug/faults';

  static const patterns = [
    splash,
    login,
    register,
    forgotPassword,
    home,
    accountDetail,
    offerDetail,
    fx,
    profile,
    debugFaults,
  ];

  /// Rutas accesibles sin sesión.
  static const public = {splash, login, register, forgotPassword};

  static String account(String accountId) =>
      '/accounts/${Uri.encodeComponent(accountId)}';

  static String offer(String offerId) =>
      '/offers/${Uri.encodeComponent(offerId)}';

  /// `true` si [route] (con o sin query) coincide con alguna ruta declarada.
  /// Se usa para validar deep links de push y del servidor (SDUI).
  static bool isKnown(String route) {
    final path = _pathOf(route);
    if (path == null) return false;
    return patterns.any((pattern) => _matches(pattern, path));
  }

  static bool isPublic(String route) {
    final path = _pathOf(route);
    return path != null && public.contains(path);
  }

  static String? _pathOf(String route) {
    final uri = Uri.tryParse(route.trim());
    if (uri == null || uri.hasScheme || uri.hasAuthority) return null;
    final path = uri.path;
    if (!path.startsWith('/')) return null;
    return path.length > 1 && path.endsWith('/')
        ? path.substring(0, path.length - 1)
        : path;
  }

  static bool _matches(String pattern, String path) {
    final expected = pattern.split('/');
    final actual = path.split('/');
    if (expected.length != actual.length) return false;
    for (var i = 0; i < expected.length; i++) {
      final segment = expected[i];
      if (segment.startsWith(':')) {
        if (actual[i].isEmpty) return false;
      } else if (segment != actual[i]) {
        return false;
      }
    }
    return true;
  }
}
