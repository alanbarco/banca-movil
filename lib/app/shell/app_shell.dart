import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_routes.dart';
import '../../core/session/session_timeout_service.dart';

class ShellDestination {
  const ShellDestination({
    required this.path,
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String path;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// Contenedor de las pestañas principales.
///
/// El `Listener` raíz reinicia el temporizador de inactividad en cada toque
/// (FR-007).
class AppShell extends StatelessWidget {
  const AppShell({
    required this.location,
    required this.destinations,
    required this.sessionTimeout,
    required this.child,
    this.isTabEnabled,
    this.tabChanges,
    super.key,
  });

  static const all = [
    ShellDestination(
      path: AppRoutes.home,
      label: 'Inicio',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
    ),
    ShellDestination(
      path: AppRoutes.fx,
      label: 'Divisas',
      icon: Icons.currency_exchange_outlined,
      selectedIcon: Icons.currency_exchange,
    ),
    ShellDestination(
      path: AppRoutes.profile,
      label: 'Perfil',
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
    ),
  ];

  /// Pestañas cuya ruta ya registró alguna feature.
  static List<ShellDestination> destinationsFor(List<RouteBase> shellRoutes) {
    final paths = {
      for (final route in shellRoutes)
        if (route is GoRoute) route.path,
    };
    return [
      for (final destination in all)
        if (paths.contains(destination.path)) destination,
    ];
  }

  final String location;
  final List<ShellDestination> destinations;
  final SessionTimeoutService sessionTimeout;
  final Widget child;

  /// Oculta pestañas cuyo flag está apagado para el cliente (p. ej. Divisas
  /// con `fx_service`, escenario US3-3).
  final bool Function(String path)? isTabEnabled;

  /// Avisa cuando hay que volver a evaluar [isTabEnabled].
  final Listenable? tabChanges;

  List<ShellDestination> get _visible => [
    for (final destination in destinations)
      if (isTabEnabled?.call(destination.path) ?? true) destination,
  ];

  int _selectedIndex(List<ShellDestination> destinations) {
    final index = destinations.indexWhere(
      (d) => location == d.path || location.startsWith('${d.path}/'),
    );
    return index < 0 ? 0 : index;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => sessionTimeout.registerInteraction(),
      child: Scaffold(
        body: child,
        bottomNavigationBar: ListenableBuilder(
          listenable: tabChanges ?? const _NoChanges(),
          builder: (context, _) =>
              _navigationBar(context) ?? const SizedBox.shrink(),
        ),
      ),
    );
  }

  Widget? _navigationBar(BuildContext context) {
    final destinations = _visible;
    // NavigationBar exige al menos 2 destinos.
    if (destinations.length < 2) return null;
    return NavigationBar(
      selectedIndex: _selectedIndex(destinations),
      onDestinationSelected: (index) => context.go(destinations[index].path),
      destinations: [
        for (final d in destinations)
          NavigationDestination(
            icon: Icon(d.icon),
            selectedIcon: Icon(d.selectedIcon),
            label: d.label,
          ),
      ],
    );
  }
}

class _NoChanges implements Listenable {
  const _NoChanges();

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}
