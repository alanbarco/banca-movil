import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';

/// Abre una ruta definida por el banco en el layout.
///
/// Solo se navega a rutas declaradas en `ui-routes.md` (un servidor no puede
/// mandar a la app a una URL arbitraria). Los detalles se apilan sobre el
/// inicio; las pestañas del shell se reemplazan.
void openSduiRoute(BuildContext context, String? route) {
  if (route == null || !AppRoutes.isKnown(route)) return;
  final path = Uri.parse(route).path;
  final isDetail = path.startsWith('/offers/') || path.startsWith('/accounts/');
  if (isDetail) {
    context.push(route);
  } else {
    context.go(route);
  }
}
