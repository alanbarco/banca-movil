/// Segmento de cliente elegido en el onboarding (FR-003).
enum Segment {
  student,
  professional,
  entrepreneur;

  /// Valor guardado en Firestore y usado por Remote Config.
  String get wireName => name;

  static Segment? fromWire(Object? value) {
    for (final segment in values) {
      if (segment.name == value) return segment;
    }
    return null;
  }
}
