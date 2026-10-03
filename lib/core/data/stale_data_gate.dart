import 'dart:async';

import '../connectivity/connectivity_status.dart';

/// Decide cuándo los datos de caché se muestran como desactualizados
/// (FR-028): si no hay conexión, o si el servidor no los confirma en
/// [grace].
///
/// Firestore entrega primero la caché y milisegundos después la respuesta
/// del servidor; sin esta espera el aviso "Sin conexión" parpadearía al abrir
/// cualquier pantalla.
class StaleDataGate {
  StaleDataGate({
    required ConnectivityStatus connectivity,
    required void Function() onChange,
    this.grace = defaultGrace,
  }) : _connectivity = connectivity,
       _onChange = onChange {
    _subscription = connectivity.onlineChanges.listen((_) => onChange());
  }

  static const defaultGrace = Duration(seconds: 5);

  final ConnectivityStatus _connectivity;
  final void Function() _onChange;
  final Duration grace;
  late final StreamSubscription<bool> _subscription;

  bool _fromCache = false;
  bool _expired = false;
  Timer? _timer;

  /// `true` si los datos actuales deben mostrarse como desactualizados.
  bool get showStale => _fromCache && (_expired || !_connectivity.isOnline);

  /// Registra el origen del último dato recibido.
  void track({required bool fromCache}) {
    if (!fromCache) {
      reset();
      return;
    }
    _fromCache = true;
    _timer ??= Timer(grace, () {
      _expired = true;
      _onChange();
    });
  }

  void reset() {
    _timer?.cancel();
    _timer = null;
    _expired = false;
    _fromCache = false;
  }

  Future<void> dispose() async {
    reset();
    await _subscription.cancel();
  }
}
