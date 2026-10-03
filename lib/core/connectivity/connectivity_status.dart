/// Conectividad vista por las features, sin depender de `ConnectivityCubit`.
abstract interface class ConnectivityStatus {
  bool get isOnline;

  /// Emite solo cuando cambia [isOnline].
  Stream<bool> get onlineChanges;
}
