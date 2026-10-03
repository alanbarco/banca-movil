import 'dart:async';

/// Cierra la sesión tras 5 minutos sin interacción (FR-007).
///
/// `AuthBloc` llama [start] al autenticarse y [stop] al cerrar sesión; el
/// `Listener` raíz de la app llama [registerInteraction] en cada toque.
class SessionTimeoutService {
  SessionTimeoutService({this.timeout = const Duration(minutes: 5)});

  final Duration timeout;
  final _timeouts = StreamController<void>.broadcast();
  Timer? _timer;

  Stream<void> get timeouts => _timeouts.stream;

  bool get isActive => _timer?.isActive ?? false;

  void start() => _restart();

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Reinicia la cuenta solo si hay una sesión vigilada.
  void registerInteraction() {
    if (isActive) _restart();
  }

  void _restart() {
    _timer?.cancel();
    _timer = Timer(timeout, () {
      _timer = null;
      _timeouts.add(null);
    });
  }

  Future<void> dispose() async {
    stop();
    await _timeouts.close();
  }
}
