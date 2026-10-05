import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../core/modules/feature_module.dart';
import '../../core/notifications/notifications_toggle.dart';
import 'data/datasources/devices_datasource.dart';
import 'data/datasources/fcm_datasource.dart';
import 'data/repositories/notifications_repository_impl.dart';
import 'domain/repositories/notifications_repository.dart';
import 'domain/usecases/resolve_push_route.dart';
import 'domain/usecases/set_notifications_enabled.dart';
import 'presentation/bloc/notifications_cubit.dart';
import 'presentation/push_route_opener.dart';
import 'presentation/widgets/in_app_notification_listener.dart';

class NotificationsModule extends FeatureModule {
  const NotificationsModule();

  @override
  void register(GetIt getIt) {
    // Con la app cerrada o en segundo plano, FCM muestra la notificación del
    // sistema por sí solo; el handler solo debe existir.
    FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);
    getIt
      ..registerLazySingleton(FcmDatasource.new)
      ..registerLazySingleton(
        () => DevicesDatasource(FirebaseFirestore.instance),
      )
      ..registerLazySingleton<NotificationsRepository>(
        () => NotificationsRepositoryImpl(
          fcm: getIt(),
          devices: getIt(),
          sessionEvents: getIt(),
          currentUser: getIt(),
        ),
      )
      ..registerLazySingleton<NotificationsToggle>(
        () => SetNotificationsEnabled(getIt()),
      )
      ..registerLazySingleton(
        () => ResolvePushRoute(session: getIt(), pending: getIt()),
      )
      ..registerLazySingleton(
        () => PushRouteOpener(
          repository: getIt(),
          resolveRoute: getIt(),
          observability: getIt(),
        ),
      )
      ..registerFactory(
        () => NotificationsCubit(
          repository: getIt(),
          toggle: getIt(),
          resolveRoute: getIt(),
          flags: getIt(),
          currentUser: getIt(),
          storage: getIt(),
          observability: getIt(),
        ),
      );
  }

  /// Crea el repositorio ya (debe oír el `SignedIn` del arranque) y abre la
  /// pantalla de la push que lanzó la app, si la hubo.
  @override
  void onAppReady(GoRouter router) {
    unawaited(GetIt.instance<PushRouteOpener>().start(router));
  }

  @override
  Widget wrapShell(Widget shell) => BlocProvider(
    create: (_) => GetIt.instance<NotificationsCubit>()..start(),
    child: InAppNotificationListener(child: shell),
  );
}

@pragma('vm:entry-point')
Future<void> _onBackgroundMessage(RemoteMessage message) async {}
