import 'package:equatable/equatable.dart';

/// Datos entregados por un repositorio junto con su frescura.
///
/// `isStale` es `true` cuando provienen de caché local (sin confirmación del
/// servidor); `lastSyncedAt` es la última sincronización real conocida.
class DataSnapshot<T> extends Equatable {
  const DataSnapshot({
    required this.data,
    this.isStale = false,
    this.lastSyncedAt,
  });

  final T data;
  final bool isStale;
  final DateTime? lastSyncedAt;

  DataSnapshot<R> map<R>(R Function(T data) transform) {
    return DataSnapshot(
      data: transform(data),
      isStale: isStale,
      lastSyncedAt: lastSyncedAt,
    );
  }

  @override
  List<Object?> get props => [data, isStale, lastSyncedAt];
}
