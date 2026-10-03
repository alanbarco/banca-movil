import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/connectivity/connectivity_status.dart';
import '../../../../core/data/data_snapshot.dart';
import '../../../../core/data/load_status.dart';
import '../../../../core/data/stale_data_gate.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/observability/analytics_events.dart';
import '../../../../core/observability/observability_service.dart';
import '../../../../core/session/current_user_profile.dart';

/// Escucha un stream en vivo del cliente actual y lo traduce a los estados
/// de `data-model.md` (loading → success / stale / empty / failure).
///
/// Los datos de caché se muestran de inmediato, pero solo pasan a `stale`
/// (banner "Sin conexión") según [StaleDataGate].
abstract class LiveDataCubit<T> extends Cubit<LoadState<T>> {
  LiveDataCubit({
    required CurrentUserProfile currentUser,
    required ConnectivityStatus connectivity,
    required ObservabilityService observability,
    required this.feature,
    Duration staleGrace = StaleDataGate.defaultGrace,
  }) : _currentUser = currentUser,
       _observability = observability,
       super(const LoadState.initial()) {
    _gate = StaleDataGate(
      connectivity: connectivity,
      onChange: _render,
      grace: staleGrace,
    );
  }

  final CurrentUserProfile _currentUser;
  final ObservabilityService _observability;
  late final StaleDataGate _gate;

  /// Valor de `feature` en los eventos de analítica.
  final String feature;

  StreamSubscription<Result<DataSnapshot<T?>>>? _subscription;
  DataSnapshot<T?>? _last;

  /// Datos del cliente; `data == null` significa "no hay nada que mostrar".
  Stream<Result<DataSnapshot<T?>>> watch(String uid);

  /// Estado cuando el servidor confirma que no hay datos.
  LoadState<T> whenMissing();

  void start() {
    unawaited(_subscription?.cancel());
    _forget();
    final uid = _currentUser.current?.uid;
    if (uid == null) {
      _fail(const Failure.unauthorized());
      return;
    }
    emit(LoadState.loading(previous: state.data));
    _subscription = watch(uid).listen((result) {
      if (!isClosed) result.fold(_fail, _onSnapshot);
    });
  }

  void retry() => start();

  void _onSnapshot(DataSnapshot<T?> snapshot) {
    _last = snapshot;
    _gate.track(fromCache: snapshot.isStale);
    _render();
  }

  void _render() {
    final snapshot = _last;
    if (snapshot == null || isClosed) return;
    final data = snapshot.data;
    if (data == null) {
      // Una caché vacía no prueba que no haya datos: se sigue esperando al
      // servidor (con el banner offline global visible si no hay red).
      if (!snapshot.isStale) emit(whenMissing());
      return;
    }
    if (!_gate.showStale) {
      emit(LoadState.success(data));
      return;
    }
    if (state.status != LoadStatus.stale) {
      unawaited(
        _observability.logEvent(AnalyticsEvents.staleDataShown, {
          AnalyticsParams.feature: feature,
        }),
      );
    }
    emit(LoadState.stale(data, lastSyncedAt: snapshot.lastSyncedAt));
  }

  void _fail(Failure failure) {
    _forget();
    unawaited(
      _observability.logEvent(AnalyticsEvents.dataLoadError, {
        AnalyticsParams.feature: feature,
        AnalyticsParams.reason: failure.reason,
      }),
    );
    emit(LoadState.failure(failure, previous: state.data));
  }

  void _forget() {
    _last = null;
    _gate.reset();
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    await _gate.dispose();
    return super.close();
  }
}
