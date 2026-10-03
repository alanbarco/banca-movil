/// Puerta única para analítica y reporte de errores (constitución VI).
///
/// Los parámetros NUNCA deben contener PII: ver
/// `specs/001-digital-banking-mvp/contracts/analytics-events.md`.
abstract interface class ObservabilityService {
  Future<void> logEvent(String name, [Map<String, Object>? parameters]);

  Future<void> recordError(
    Object error,
    StackTrace? stackTrace, {
    String? reason,
    bool fatal,
  });

  Future<void> setUserProperty(String name, String? value);

  Future<void> setUserId(String? id);
}

/// Implementación vacía para tests y entornos sin Firebase.
class NoopObservabilityService implements ObservabilityService {
  const NoopObservabilityService();

  @override
  Future<void> logEvent(String name, [Map<String, Object>? parameters]) async {}

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stackTrace, {
    String? reason,
    bool fatal = false,
  }) async {}

  @override
  Future<void> setUserProperty(String name, String? value) async {}

  @override
  Future<void> setUserId(String? id) async {}
}
