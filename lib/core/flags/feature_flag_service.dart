/// Contrato de flags consumido por features y router.
abstract interface class FeatureFlagService {
  bool isEnabled(String key, {String? segment});

  /// Emite cuando los flags cambian (actualización en tiempo real).
  Stream<void> get changes;
}
