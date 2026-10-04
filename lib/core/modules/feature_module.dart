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
}
