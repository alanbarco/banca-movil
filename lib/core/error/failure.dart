import 'package:equatable/equatable.dart';

/// Falla de dominio tipada. Las capas `data` traducen excepciones técnicas
/// (Firebase, dio, simulador) a una de estas variantes.
sealed class Failure extends Equatable {
  const Failure();

  const factory Failure.network() = NetworkFailure;
  const factory Failure.timeout() = TimeoutFailure;
  const factory Failure.unauthorized() = UnauthorizedFailure;
  const factory Failure.notFound() = NotFoundFailure;
  const factory Failure.validation(String field) = ValidationFailure;
  const factory Failure.server() = ServerFailure;
  const factory Failure.unknown([Object? cause]) = UnknownFailure;

  /// Motivo corto y sin PII, apto para eventos de analítica.
  String get reason;

  @override
  List<Object?> get props => const [];
}

final class NetworkFailure extends Failure {
  const NetworkFailure();

  @override
  String get reason => 'network';
}

final class TimeoutFailure extends Failure {
  const TimeoutFailure();

  @override
  String get reason => 'timeout';
}

final class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure();

  @override
  String get reason => 'unauthorized';
}

final class NotFoundFailure extends Failure {
  const NotFoundFailure();

  @override
  String get reason => 'not_found';
}

final class ValidationFailure extends Failure {
  const ValidationFailure(this.field);

  /// Campo del formulario que no pasó la validación (p. ej. `email`).
  final String field;

  @override
  String get reason => 'validation';

  @override
  List<Object?> get props => [field];
}

final class ServerFailure extends Failure {
  const ServerFailure();

  @override
  String get reason => 'server';
}

final class UnknownFailure extends Failure {
  const UnknownFailure([this.cause]);

  /// Excepción original; no participa de la igualdad.
  final Object? cause;

  @override
  String get reason => 'other';
}
