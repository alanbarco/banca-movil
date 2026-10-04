import 'dart:async';

import 'package:firebase_core/firebase_core.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/fault_injection/fault_config.dart';
import '../../../../core/fault_injection/fault_runner.dart';
import '../../../../core/observability/app_logger.dart';
import '../../../../core/observability/observability_service.dart';
import '../../domain/entities/home_layout.dart';
import '../../domain/repositories/home_layout_repository.dart';
import '../datasources/home_layout_remote_config_datasource.dart';
import '../models/home_layout_model.dart';

/// Layout del inicio desde Remote Config, con el simulador de fallos de
/// `personalization` aplicado (FR-032).
class HomeLayoutRepositoryImpl implements HomeLayoutRepository {
  HomeLayoutRepositoryImpl({
    required HomeLayoutRemoteConfigDatasource datasource,
    required FaultRunner faults,
    required ObservabilityService observability,
    AppLogger? logger,
  }) : _datasource = datasource,
       _faults = faults,
       _observability = observability,
       _logger = logger ?? AppLogger('personalization');

  final HomeLayoutRemoteConfigDatasource _datasource;
  final FaultRunner _faults;
  final ObservabilityService _observability;
  final AppLogger _logger;

  HomeLayout? _current;
  late final HomeLayout _localDefaults = HomeLayoutModel.fromJson(
    _datasource.localDefaults(),
  );

  @override
  HomeLayout get localDefaults => _localDefaults;

  @override
  HomeLayout? get current => _current;

  /// Con un `async*` + `await for`, cancelar la suscripción no completa
  /// nunca; por eso se cancela la escucha de cambios a mano.
  @override
  Stream<Result<HomeLayout>> watchLayout() {
    StreamSubscription<Result<HomeLayout>>? changes;
    late final StreamController<Result<HomeLayout>> controller;
    controller = StreamController(
      onListen: () {
        changes = _datasource.changes
            .asyncMap((_) => _read())
            .listen(controller.add);
        unawaited(
          _read().then((result) {
            if (!controller.isClosed) controller.add(result);
          }),
        );
      },
      onCancel: () => changes?.cancel(),
    );
    return controller.stream;
  }

  Future<Result<HomeLayout>> _read() async {
    try {
      final json = await _faults.runWithFaults(
        FaultTarget.personalization,
        () async => _datasource.read(),
      );
      final layout = HomeLayoutModel.fromJson(json);
      _current = layout;
      return Success(layout);
    } on Object catch (error, stackTrace) {
      return Err(_fail('read_layout', error, stackTrace));
    }
  }

  @override
  Future<Result<void>> refresh() async {
    try {
      await _faults.runWithFaults(
        FaultTarget.personalization,
        _datasource.refresh,
      );
      return const Success(null);
    } on Object catch (error, stackTrace) {
      return Err(_fail('refresh_layout', error, stackTrace));
    }
  }

  Failure _fail(String operation, Object error, StackTrace stackTrace) {
    final failure = mapError(error);
    _logger.warning('$operation falló', {'reason': failure.reason});
    if (failure is UnknownFailure) {
      unawaited(
        _observability.recordError(error, stackTrace, reason: operation),
      );
    }
    return failure;
  }

  static Failure mapError(Object error) {
    if (error is SimulatedFaultException) {
      return error.mode == FaultMode.offline
          ? const Failure.network()
          : const Failure.server();
    }
    if (error is TimeoutException) return const Failure.timeout();
    // `fetchAndActivate` sin red o con el servidor caído.
    if (error is FirebaseException) return const Failure.network();
    return Failure.unknown(error);
  }
}
