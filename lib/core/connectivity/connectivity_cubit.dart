import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../observability/analytics_events.dart';
import '../observability/observability_service.dart';

class ConnectivityState extends Equatable {
  const ConnectivityState({
    this.deviceOnline = true,
    this.forcedOffline = false,
  });

  /// Conectividad reportada por el sistema operativo.
  final bool deviceOnline;

  /// Modo "sin conexión" forzado desde el simulador de fallos.
  final bool forcedOffline;

  bool get isOnline => deviceOnline && !forcedOffline;

  ConnectivityState copyWith({bool? deviceOnline, bool? forcedOffline}) {
    return ConnectivityState(
      deviceOnline: deviceOnline ?? this.deviceOnline,
      forcedOffline: forcedOffline ?? this.forcedOffline,
    );
  }

  @override
  List<Object?> get props => [deviceOnline, forcedOffline];
}

/// Conectividad global para el banner offline y la recarga al reconectar
/// (FR-029).
class ConnectivityCubit extends Cubit<ConnectivityState> {
  ConnectivityCubit({
    required Connectivity connectivity,
    required ObservabilityService observability,
    Stream<bool>? forcedOfflineChanges,
  }) : _connectivity = connectivity,
       _observability = observability,
       _forcedOfflineChanges = forcedOfflineChanges,
       super(const ConnectivityState());

  final Connectivity _connectivity;
  final ObservabilityService _observability;
  final Stream<bool>? _forcedOfflineChanges;
  final List<StreamSubscription<Object?>> _subscriptions = [];

  Future<void> start() async {
    _subscriptions.add(_connectivity.onConnectivityChanged.listen(_onResults));
    final forced = _forcedOfflineChanges;
    if (forced != null) {
      _subscriptions.add(forced.listen(setForcedOffline));
    }
    _onResults(await _connectivity.checkConnectivity());
  }

  void setForcedOffline(bool forcedOffline) {
    _update(state.copyWith(forcedOffline: forcedOffline));
  }

  void _onResults(List<ConnectivityResult> results) {
    final online = results.any((r) => r != ConnectivityResult.none);
    _update(state.copyWith(deviceOnline: online));
  }

  void _update(ConnectivityState next) {
    if (isClosed || next == state) return;
    final changed = next.isOnline != state.isOnline;
    emit(next);
    if (changed) {
      unawaited(
        _observability.logEvent(AnalyticsEvents.connectivityChanged, {
          AnalyticsParams.online: next.isOnline,
        }),
      );
    }
  }

  @override
  Future<void> close() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    return super.close();
  }
}
