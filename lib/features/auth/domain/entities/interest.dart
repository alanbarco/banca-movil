/// Catálogo de intereses definido por el banco (FR-003).
enum Interest {
  savings,
  investment,
  travel,
  education,
  business;

  String get wireName => name;

  static Interest? fromWire(Object? value) {
    for (final interest in values) {
      if (interest.name == value) return interest;
    }
    return null;
  }
}
