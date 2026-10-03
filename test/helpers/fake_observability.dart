import 'package:bi_app/core/observability/observability_service.dart';

class LoggedEvent {
  const LoggedEvent(this.name, this.parameters);

  final String name;
  final Map<String, Object> parameters;

  @override
  String toString() => 'LoggedEvent($name, $parameters)';
}

/// Registra en memoria lo que la app reporta, para verificarlo en tests.
class FakeObservabilityService implements ObservabilityService {
  final events = <LoggedEvent>[];
  final errors = <Object>[];
  final userProperties = <String, String?>{};
  String? userId;

  Iterable<LoggedEvent> named(String name) =>
      events.where((event) => event.name == name);

  @override
  Future<void> logEvent(String name, [Map<String, Object>? parameters]) async {
    events.add(LoggedEvent(name, parameters ?? const {}));
  }

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stackTrace, {
    String? reason,
    bool fatal = false,
  }) async {
    errors.add(error);
  }

  @override
  Future<void> setUserProperty(String name, String? value) async {
    userProperties[name] = value;
  }

  @override
  Future<void> setUserId(String? id) async {
    userId = id;
  }
}
