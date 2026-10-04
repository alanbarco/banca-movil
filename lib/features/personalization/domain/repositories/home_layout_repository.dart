import '../../../../core/error/result.dart';
import '../entities/home_layout.dart';

/// Layout del inicio definido por el banco (Remote Config).
abstract interface class HomeLayoutRepository {
  /// Layout vigente y cada actualización publicada por el banco. El stream
  /// no termina ante fallas: llegan como `Err`.
  Stream<Result<HomeLayout>> watchLayout();

  /// Configuración predeterminada segura incluida en la app (FR-017).
  HomeLayout get localDefaults;

  /// Último layout leído con éxito, si lo hay.
  HomeLayout? get current;

  /// Pide la configuración al servidor (pull-to-refresh).
  Future<Result<void>> refresh();
}
