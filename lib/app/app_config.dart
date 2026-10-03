/// Configuración de compilación (`--dart-define-from-file=.env`).
abstract final class AppConfig {
  /// Habilita las herramientas de demo (panel de fallos). Nunca en producción.
  static const demoTools = bool.fromEnvironment('DEMO_TOOLS');
}
