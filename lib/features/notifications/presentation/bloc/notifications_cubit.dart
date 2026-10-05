import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/flags/feature_flag_service.dart';
import '../../../../core/flags/flag_keys.dart';
import '../../../../core/notifications/notifications_toggle.dart';
import '../../../../core/observability/analytics_events.dart';
import '../../../../core/observability/observability_service.dart';
import '../../../../core/session/current_user_profile.dart';
import '../../../../core/storage/local_storage.dart';
import '../../domain/entities/push_message.dart';
import '../../domain/repositories/notifications_repository.dart';
import '../../domain/usecases/resolve_push_route.dart';

class NotificationsState extends Equatable {
  const NotificationsState({this.inApp, this.showExplainer = false});

  /// Llegó con la app abierta: se muestra como aviso in-app (FR-025).
  final PushMessage? inApp;

  /// Toca explicar para qué son las push antes de pedir el permiso.
  final bool showExplainer;

  @override
  List<Object?> get props => [inApp, showExplainer];
}

/// Aviso in-app y explicación previa del permiso (FR-023, FR-025).
class NotificationsCubit extends Cubit<NotificationsState> {
  NotificationsCubit({
    required NotificationsRepository repository,
    required NotificationsToggle toggle,
    required ResolvePushRoute resolveRoute,
    required FeatureFlagService flags,
    required CurrentUserProfile currentUser,
    required LocalStorage storage,
    required ObservabilityService observability,
    Duration inAppTimeout = defaultInAppTimeout,
  }) : _repository = repository,
       _toggle = toggle,
       _resolveRoute = resolveRoute,
       _flags = flags,
       _currentUser = currentUser,
       _storage = storage,
       _observability = observability,
       _inAppTimeout = inAppTimeout,
       super(const NotificationsState());

  /// La explicación se muestra una sola vez por dispositivo.
  static const explainerShownKey = 'push_explainer_shown';

  /// Tiempo máximo del aviso in-app en pantalla si el cliente no lo toca.
  static const defaultInAppTimeout = Duration(seconds: 7);

  final NotificationsRepository _repository;
  final NotificationsToggle _toggle;
  final ResolvePushRoute _resolveRoute;
  final FeatureFlagService _flags;
  final CurrentUserProfile _currentUser;
  final LocalStorage _storage;
  final ObservabilityService _observability;
  final Duration _inAppTimeout;
  StreamSubscription<PushMessage>? _foreground;
  Timer? _inAppTimer;

  Future<void> start() async {
    _foreground = _repository.foregroundMessages.listen(_showInApp);
    if (await _shouldExplain() && !isClosed) {
      emit(NotificationsState(inApp: state.inApp, showExplainer: true));
    }
  }

  /// El cliente aceptó la explicación: se pide el permiso del sistema.
  Future<void> acceptExplainer() async {
    await _markExplained();
    await _toggle.setEnabled(enabled: true);
  }

  Future<void> declineExplainer() => _markExplained();

  void dismiss() {
    _inAppTimer?.cancel();
    emit(const NotificationsState());
  }

  /// Tocó "Ver" en el aviso: devuelve la ruta a abrir.
  String? open(PushMessage message) {
    logOpened(_observability, message);
    dismiss();
    return _resolveRoute(message.route);
  }

  static void logOpened(
    ObservabilityService observability,
    PushMessage message,
  ) => unawaited(
    observability.logEvent(AnalyticsEvents.pushOpened, {
      AnalyticsParams.type: message.type.name,
    }),
  );

  /// Cada aviso nuevo reinicia el conteo; si nadie lo toca, se cierra solo.
  void _showInApp(PushMessage message) {
    _inAppTimer?.cancel();
    emit(NotificationsState(inApp: message));
    _inAppTimer = Timer(_inAppTimeout, () {
      if (!isClosed) dismiss();
    });
  }

  Future<bool> _shouldExplain() async {
    final user = _currentUser.current;
    if (user == null) return false;
    if (_storage.getBool(explainerShownKey) ?? false) return false;
    if (!_flags.isEnabled(FlagKeys.pushOptInPrompt, segment: user.segment)) {
      return false;
    }
    // El permiso es de cada dispositivo: aunque la cuenta ya tenga las push
    // activadas (en otro celular), aquí aún no se pidió. Si ya lo concedió o
    // lo negó en el sistema, no se insiste (FR-023).
    return await _repository.permission() == PushPermission.notDetermined;
  }

  Future<void> _markExplained() async {
    await _storage.setBool(explainerShownKey, value: true);
    if (!isClosed) emit(NotificationsState(inApp: state.inApp));
  }

  @override
  Future<void> close() async {
    _inAppTimer?.cancel();
    await _foreground?.cancel();
    return super.close();
  }
}
