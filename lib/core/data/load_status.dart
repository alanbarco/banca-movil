import 'package:equatable/equatable.dart';

import '../error/failure.dart';

/// Estados explícitos que toda pantalla con datos remotos debe representar.
enum LoadStatus { initial, loading, success, stale, empty, failure }

/// Estado de carga reutilizable por los Cubits de las features.
class LoadState<T> extends Equatable {
  const LoadState._({
    required this.status,
    this.data,
    this.failure,
    this.lastSyncedAt,
  });

  const LoadState.initial() : this._(status: LoadStatus.initial);

  const LoadState.loading({T? previous})
    : this._(status: LoadStatus.loading, data: previous);

  const LoadState.success(T data)
    : this._(status: LoadStatus.success, data: data);

  const LoadState.stale(T data, {DateTime? lastSyncedAt})
    : this._(status: LoadStatus.stale, data: data, lastSyncedAt: lastSyncedAt);

  const LoadState.empty({DateTime? lastSyncedAt})
    : this._(status: LoadStatus.empty, lastSyncedAt: lastSyncedAt);

  const LoadState.failure(Failure failure, {T? previous})
    : this._(status: LoadStatus.failure, failure: failure, data: previous);

  final LoadStatus status;
  final T? data;
  final Failure? failure;
  final DateTime? lastSyncedAt;

  bool get hasData => data != null;

  @override
  List<Object?> get props => [status, data, failure, lastSyncedAt];
}
