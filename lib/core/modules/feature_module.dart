import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

/// Punto de entrada de cada feature: registra sus dependencias (y sus
/// secciones SDUI) y declara sus rutas. `app/` solo compone módulos.
abstract class FeatureModule {
  const FeatureModule();

  void register(GetIt getIt);

  /// Rutas a pantalla completa, fuera del shell (login, detalle de cuenta…).
  List<RouteBase> get routes => const [];

  /// Rutas de las pestañas del shell (`/home`, `/fx`, `/profile`).
  List<RouteBase> get shellRoutes => const [];

  /// Envuelve el shell (p. ej. avisos in-app de push). Solo se usa con
  /// sesión iniciada.
  Widget wrapShell(Widget shell) => shell;

  /// Se llama una vez creado el router, antes de `runApp` (p. ej. para abrir
  /// la pantalla de una push que lanzó la app).
  void onAppReady(GoRouter router) {}
}
