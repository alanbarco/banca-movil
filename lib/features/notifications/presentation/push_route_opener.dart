import 'dart:async';

import 'package:go_router/go_router.dart';

import '../../../core/observability/observability_service.dart';
import '../../../core/routing/app_routes.dart';
import '../domain/entities/push_message.dart';
import '../domain/repositories/notifications_repository.dart';
import '../domain/usecases/resolve_push_route.dart';
import 'bloc/notifications_cubit.dart';

/// Abre la pantalla de una push tocada con la app cerrada o en segundo plano
/// (FR-026). Vive a nivel de app porque puede llegar antes del login.
class PushRouteOpener {
  PushRouteOpener({
    required NotificationsRepository repository,
    required ResolvePushRoute resolveRoute,
    required ObservabilityService observability,
  }) : _repository = repository,
       _resolveRoute = resolveRoute,
       _observability = observability;

  final NotificationsRepository _repository;
  final ResolvePushRoute _resolveRoute;
  final ObservabilityService _observability;
  StreamSubscription<PushMessage>? _subscription;

  Future<void> start(GoRouter router) async {
    _subscription = _repository.openedMessages.listen(
      (message) => _open(message, router),
    );
    final initial = await _repository.initialMessage();
    if (initial != null) _open(initial, router);
  }

  void _open(PushMessage message, GoRouter router) {
    NotificationsCubit.logOpened(_observability, message);
    // Sin sesión, la ruta queda pendiente y el guard la abre tras el login.
    final route = _resolveRoute(message.route);
    if (route != null) openPushRoute(router, route);
  }

  Future<void> dispose() async => _subscription?.cancel();
}

/// Los detalles (cuenta, oferta) se apilan sobre el inicio para poder volver;
/// las pestañas se reemplazan.
void openPushRoute(GoRouter router, String route) {
  final path = Uri.parse(route).path;
  final isDetail = path.startsWith('/offers/') || path.startsWith('/accounts/');
  if (!isDetail) {
    router.go(route);
    return;
  }
  router.go(AppRoutes.home);
  unawaited(router.push<void>(route));
}
