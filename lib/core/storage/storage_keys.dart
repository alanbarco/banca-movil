/// Claves de `LocalStorage` compartidas entre `app` y las features.
abstract final class StorageKeys {
  /// Marcada al cerrar sesión; el siguiente arranque borra la caché de
  /// Firestore antes de cualquier lectura (FR-008).
  static const pendingCacheClear = 'pending_cache_clear';

  /// Correo precargado en el login tras cierre por inactividad (no es
  /// credencial).
  static const lastSignedInEmail = 'last_signed_in_email';
}
