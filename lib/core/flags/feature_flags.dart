import 'package:equatable/equatable.dart';

class FlagRule extends Equatable {
  const FlagRule({required this.enabled, this.segments = const []});

  final bool enabled;

  /// Vacío = todos los segmentos.
  final List<String> segments;

  bool appliesTo(String? segment) {
    if (!enabled) return false;
    if (segments.isEmpty) return true;
    return segment != null && segments.contains(segment);
  }

  @override
  List<Object?> get props => [enabled, segments];
}

/// Contenido del parámetro `feature_flags` ya validado.
class FeatureFlags extends Equatable {
  const FeatureFlags(this.rules);

  /// Ignora las entradas mal formadas en lugar de descartar todo el parámetro.
  factory FeatureFlags.fromJson(Map<String, dynamic> json) {
    final flags = json['flags'];
    if (flags is! Map<String, dynamic>) return const FeatureFlags({});
    final rules = <String, FlagRule>{};
    for (final entry in flags.entries) {
      final value = entry.value;
      if (value is! Map<String, dynamic>) continue;
      final enabled = value['enabled'];
      if (enabled is! bool) continue;
      final segments = value['segments'];
      rules[entry.key] = FlagRule(
        enabled: enabled,
        segments: segments is List ? segments.whereType<String>().toList() : [],
      );
    }
    return FeatureFlags(rules);
  }

  final Map<String, FlagRule> rules;

  /// `null` si el flag no está definido.
  bool? evaluate(String key, {String? segment}) =>
      rules[key]?.appliesTo(segment);

  /// Evalúa [key]; si no existe aquí se usa [defaults] y, en último caso,
  /// `false` (apagado es el valor seguro).
  bool isEnabled(String key, {String? segment, FeatureFlags? defaults}) {
    return evaluate(key, segment: segment) ??
        defaults?.evaluate(key, segment: segment) ??
        false;
  }

  @override
  List<Object?> get props => [rules];
}
