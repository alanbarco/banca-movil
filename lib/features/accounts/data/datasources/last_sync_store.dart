import '../../../../core/storage/local_storage.dart';

/// Hora de la última lectura confirmada por el servidor, para el aviso
/// "actualizado a las HH:mm" cuando se muestran datos de caché (FR-028).
class LastSyncStore {
  LastSyncStore(this._storage, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final LocalStorage _storage;
  final DateTime Function() _clock;

  static String keyFor(String uid) => 'accounts_last_sync_$uid';

  DateTime? lastSyncedAt(String uid) {
    final raw = _storage.getString(keyFor(uid));
    return raw == null ? null : DateTime.tryParse(raw);
  }

  /// Registra una sincronización ahora y devuelve la hora guardada.
  Future<DateTime> markSynced(String uid) async {
    final now = _clock().toUtc();
    await _storage.setString(keyFor(uid), now.toIso8601String());
    return now;
  }
}
