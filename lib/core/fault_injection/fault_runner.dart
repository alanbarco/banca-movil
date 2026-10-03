import 'fault_config.dart';

/// Aplica el fallo simulado configurado antes de ejecutar una operación real.
///
/// Para Firestore el modo `offline` no lanza: la red ya está deshabilitada con
/// `disableNetwork()` y la operación debe resolverse desde la caché local.
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
      case FaultMode.error:
        throw SimulatedFaultException(target, FaultMode.error);
      case FaultMode.offline:
        if (target != FaultTarget.firestore) {
          throw SimulatedFaultException(target, FaultMode.offline);
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
      case FaultMode.error:
        throw SimulatedFaultException(target, FaultMode.error);
      case FaultMode.offline:
        if (target != FaultTarget.firestore) {
          throw SimulatedFaultException(target, FaultMode.offline);
        }
    }
    yield* source();
  }
}
