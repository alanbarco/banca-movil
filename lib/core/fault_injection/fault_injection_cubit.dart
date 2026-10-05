import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'fault_config.dart';

class FaultInjectionState extends Equatable {
  const FaultInjectionState({this.configs = const {}});

  final Map<FaultTarget, FaultConfig> configs;

  FaultConfig configFor(FaultTarget target) =>
      configs[target] ?? FaultConfig.normal;

  /// El modo "sin conexión" de Firestore también se refleja en el banner global.
  bool get forcedOffline =>
      configFor(FaultTarget.firestore).mode == FaultMode.offline;

  FaultInjectionState copyWith(FaultTarget target, FaultConfig config) {
    return FaultInjectionState(configs: {...configs, target: config});
  }

  @override
  List<Object?> get props => [configs];
}

/// Estado del panel de simulación de fallos (solo builds con `DEMO_TOOLS`).
class FaultInjectionCubit extends Cubit<FaultInjectionState>
    implements FaultConfigSource {
  FaultInjectionCubit({FirebaseFirestore? firestore})
    : _firestore = firestore,
      super(const FaultInjectionState());

  final FirebaseFirestore? _firestore;

  @override
  FaultConfig configFor(FaultTarget target) => state.configFor(target);

  Future<void> setFault(
    FaultTarget target,
    FaultMode mode, {
    int? latencyMs,
  }) async {
    final previous = state.configFor(target);
    final next = FaultConfig(
      mode: mode,
      latencyMs: latencyMs ?? previous.latencyMs,
    );
    if (target == FaultTarget.firestore) {
      await _syncFirestoreNetwork(
        wasOffline: _cutsFirestoreNetwork(previous.mode),
        isOffline: _cutsFirestoreNetwork(mode),
      );
    }
    emit(state.copyWith(target, next));
  }

  /// "Sin red" y "Error" cortan la red real de Firestore. Así reacciona el
  /// SDK ante un error de servidor (`unavailable`, 5xx): responde desde su
  /// caché y reintenta solo, sin entregar el error a la app. Solo "Sin red"
  /// muestra además el banner global de conexión.
  static bool _cutsFirestoreNetwork(FaultMode mode) =>
      mode == FaultMode.offline || mode == FaultMode.error;

  Future<void> reset() async {
    for (final target in FaultTarget.values) {
      await setFault(target, FaultMode.none);
    }
  }

  Future<void> _syncFirestoreNetwork({
    required bool wasOffline,
    required bool isOffline,
  }) async {
    final firestore = _firestore;
    if (firestore == null || wasOffline == isOffline) return;
    if (isOffline) {
      await firestore.disableNetwork();
    } else {
      await firestore.enableNetwork();
    }
  }
}
