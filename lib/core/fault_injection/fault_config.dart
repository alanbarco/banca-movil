import 'package:equatable/equatable.dart';

/// Servicios que el panel de demo puede degradar (FR-032).
enum FaultTarget { firestore, personalization, fx }

enum FaultMode { none, offline, latency, error }

class FaultConfig extends Equatable {
  const FaultConfig({this.mode = FaultMode.none, this.latencyMs = 3000});

  static const normal = FaultConfig();

  final FaultMode mode;

  /// Solo aplica cuando `mode == FaultMode.latency`.
  final int latencyMs;

  Duration get latency => Duration(milliseconds: latencyMs);

  @override
  List<Object?> get props => [mode, latencyMs];
}

/// Fuente de la configuración vigente de fallos simulados.
abstract interface class FaultConfigSource {
  FaultConfig configFor(FaultTarget target);
}

/// Error lanzado por el simulador; las capas `data` lo traducen a `Failure`.
class SimulatedFaultException implements Exception {
  const SimulatedFaultException(this.target, this.mode);

  final FaultTarget target;
  final FaultMode mode;

  @override
  String toString() => 'SimulatedFaultException(${target.name}, ${mode.name})';
}
