import 'package:equatable/equatable.dart';

import '../flags/versioned_json.dart';
import 'home_section.dart';

/// Sección descartada y el motivo (para `sdui_section_skipped`, FR-016).
class SkippedSection extends Equatable {
  const SkippedSection({required this.type, required this.reason, this.id});

  static const unknownType = 'unknown_type';
  static const invalidPayload = 'invalid_payload';
  static const invalidSection = 'invalid_section';
  static const duplicateId = 'duplicate_id';

  final String? id;
  final String type;
  final String reason;

  @override
  List<Object?> get props => [id, type, reason];
}

class HomeLayoutParseResult extends Equatable {
  const HomeLayoutParseResult({
    required this.sections,
    this.skipped = const [],
  });

  /// Secciones válidas ordenadas por `order`.
  final List<HomeSection> sections;
  final List<SkippedSection> skipped;

  @override
  List<Object?> get props => [sections, skipped];
}

/// Parser tolerante de `home_layout`: una sección inválida nunca invalida al
/// resto del inicio.
class HomeSectionParser {
  const HomeSectionParser();

  static const defaultSegment = 'default';

  /// Resuelve el layout del [segment] (o `default`).
  ///
  /// Devuelve `null` si el parámetro completo es inválido (estructura o
  /// `schemaVersion` no soportada); el llamador debe usar el último válido.
  HomeLayoutParseResult? parseLayout(
    Map<String, dynamic> json, {
    String? segment,
  }) {
    if (!isSupportedSchema(json)) return null;
    final segments = json['segments'];
    if (segments is! Map<String, dynamic>) return null;

    final layout = segments[segment] ?? segments[defaultSegment];
    if (layout is! Map<String, dynamic>) return null;
    final sections = layout['sections'];
    if (sections is! List) return null;
    return parseSections(sections);
  }

  HomeLayoutParseResult parseSections(List<dynamic> raw) {
    final sections = <HomeSection>[];
    final skipped = <SkippedSection>[];
    final ids = <String>{};

    for (final item in raw) {
      if (item is! Map<String, dynamic>) {
        skipped.add(
          const SkippedSection(
            type: 'unknown',
            reason: SkippedSection.invalidSection,
          ),
        );
        continue;
      }
      final id = item['id'];
      final typeName = item['type'];
      final order = item['order'];
      final typeLabel = typeName is String ? typeName : 'unknown';

      if (id is! String || id.isEmpty || order is! int) {
        skipped.add(
          SkippedSection(
            id: id is String ? id : null,
            type: typeLabel,
            reason: SkippedSection.invalidSection,
          ),
        );
        continue;
      }
      final type = typeName is String
          ? HomeSectionType.fromWire(typeName)
          : null;
      if (type == null) {
        skipped.add(
          SkippedSection(
            id: id,
            type: typeLabel,
            reason: SkippedSection.unknownType,
          ),
        );
        continue;
      }
      if (!ids.add(id)) {
        skipped.add(
          SkippedSection(
            id: id,
            type: typeLabel,
            reason: SkippedSection.duplicateId,
          ),
        );
        continue;
      }

      final payload = item['payload'] ?? const <String, dynamic>{};
      final interests = item['interests'];
      final flag = item['flag'];
      if (payload is! Map<String, dynamic> ||
          !_isValidPayload(type, payload) ||
          (interests != null && !_isStringList(interests)) ||
          (flag != null && flag is! String)) {
        skipped.add(
          SkippedSection(
            id: id,
            type: typeLabel,
            reason: SkippedSection.invalidPayload,
          ),
        );
        continue;
      }

      sections.add(
        HomeSection(
          id: id,
          type: type,
          order: order,
          interests: interests == null
              ? const []
              : List<String>.from(interests as List),
          flag: flag as String?,
          payload: payload,
        ),
      );
    }

    sections.sort((a, b) => a.order.compareTo(b.order));
    return HomeLayoutParseResult(sections: sections, skipped: skipped);
  }

  static bool _isValidPayload(HomeSectionType type, Map<String, dynamic> p) {
    return switch (type) {
      HomeSectionType.accountsSummary => true,
      HomeSectionType.banner =>
        _hasStrings(p, ['title', 'subtitle']) &&
            _optionalStrings(p, ['imageUrl', 'color', 'route']),
      HomeSectionType.offerCarousel => _isItemList(
        p['items'],
        (item) =>
            _hasStrings(item, ['id', 'title', 'description']) &&
            _optionalStrings(item, ['route']) &&
            (item['interests'] == null || _isStringList(item['interests'])),
      ),
      HomeSectionType.quickActions => _isItemList(
        p['items'],
        (item) =>
            _hasStrings(item, ['id', 'label', 'icon', 'route']) &&
            _optionalStrings(item, ['flag']),
      ),
      HomeSectionType.tip => _hasStrings(p, ['title', 'body']),
    };
  }

  static bool _hasStrings(Map<String, dynamic> map, List<String> keys) =>
      keys.every((k) => map[k] is String && (map[k] as String).isNotEmpty);

  static bool _optionalStrings(Map<String, dynamic> map, List<String> keys) =>
      keys.every((k) => map[k] == null || map[k] is String);

  static bool _isStringList(Object? value) =>
      value is List && value.every((e) => e is String);

  static bool _isItemList(
    Object? value,
    bool Function(Map<String, dynamic> item) isValid,
  ) {
    return value is List &&
        value.isNotEmpty &&
        value.every((e) => e is Map<String, dynamic> && isValid(e));
  }
}
