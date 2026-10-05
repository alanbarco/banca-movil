import 'fault_config.dart';

/// Aplica el fallo simulado configurado antes de ejecutar una operación real.
///
/// Para Firestore, `offline` y `error` no lanzan: la red ya está deshabilitada
/// con `disableNetwork()` y la operación se resuelve desde la caché local,
/// como lo haría el SDK ante un corte o un error de servidor real.
class FaultRunner {
  const FaultRunner(this._source);

  final FaultConfigSource _source;

  Future<T> runWithFaults<T>(
    FaultTarget target,
    Future<T> Function() action,
  ) async {
    final config = _source.configFor(target);
    switch (config.mode) {
      case FaultMode.none:
        break;
      case FaultMode.latency:
        await Future<void>.delayed(config.latency);
      case FaultMode.error || FaultMode.offline:
        if (target != FaultTarget.firestore) {
          throw SimulatedFaultException(target, config.mode);
        }
    }
    return action();
  }

  Stream<T> streamWithFaults<T>(
    FaultTarget target,
    Stream<T> Function() source,
  ) async* {
    final config = _source.configFor(target);
    switch (config.mode) {
      case FaultMode.none:
        break;
      case FaultMode.latency:
        await Future<void>.delayed(config.latency);
      case FaultMode.error || FaultMode.offline:
        if (target != FaultTarget.firestore) {
          throw SimulatedFaultException(target, config.mode);
        }
    }
    yield* source();
  }
}
