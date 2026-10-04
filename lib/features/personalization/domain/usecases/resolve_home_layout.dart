import '../../../../core/flags/feature_flag_service.dart';
import '../../../../core/sdui/home_section.dart';
import '../../../../core/sdui/home_section_parser.dart';
import '../entities/home_layout.dart';

/// Arma el inicio del cliente a partir del layout del banco (FR-014–FR-018).
///
/// Pasos:
/// 1. Elegir el layout: el del segmento → `default` → defaults locales.
/// 2. Quitar lo que no se debe mostrar: tipos que la app no sabe dibujar,
///    flags apagados y contenido dirigido a intereses que el cliente no tiene.
/// 3. Ordenar por el `order` del banco; a igual `order`, primero lo que
///    coincide con los intereses del cliente.
class ResolveHomeLayout {
  const ResolveHomeLayout(this._flags);

  static const notRendered = 'not_rendered';

  final FeatureFlagService _flags;

  ResolvedHome call({
    required HomeLayout layout,
    required HomeLayout fallback,
    required String? segment,
    List<String> interests = const [],
    bool Function(HomeSectionType type)? canRender,
  }) {
    // 1. Elegir el layout.
    final fromRemote = layout.forSegment(segment);
    final source = fromRemote ?? fallback.forSegment(segment);
    if (source == null) {
      return const ResolvedHome(sections: [], usedFallback: true);
    }

    // 2. Decidir qué secciones se muestran.
    final skipped = [...source.skipped];
    final shown = <HomeSection>[];
    for (final section in source.sections) {
      if (canRender != null && !canRender(section.type)) {
        skipped.add(
          SkippedSection(
            id: section.id,
            type: section.type.wireName,
            reason: notRendered,
          ),
        );
        continue;
      }
      if (!_flagIsOn(section.flag, segment)) continue;
      if (!_isForClient(section, interests)) continue;

      final withItems = _filterItems(section, segment, interests);
      // Sin items que mostrar (p. ej. ninguna oferta aplica) no hay sección.
      if (withItems != null) shown.add(withItems);
    }

    // 3. Ordenar.
    return ResolvedHome(
      sections: _sortByBankOrder(shown, interests),
      skipped: skipped,
      usedFallback: fromRemote == null,
    );
  }

  /// Ofertas y consejos dirigidos a ciertos intereses solo los ve quien
  /// tiene alguno de ellos. El resto de secciones se muestra a todos.
  bool _isForClient(HomeSection section, List<String> clientInterests) {
    final targetsInterests =
        section.type == HomeSectionType.offerCarousel ||
        section.type == HomeSectionType.tip;
    if (!targetsInterests || section.interests.isEmpty) return true;
    return _sharesInterest(section.interests, clientInterests);
  }

  /// Filtra los items de las secciones que tienen lista (`items`); devuelve
  /// `null` si no queda ninguno.
  HomeSection? _filterItems(
    HomeSection section,
    String? segment,
    List<String> clientInterests,
  ) {
    return switch (section.type) {
      HomeSectionType.quickActions => _withItems(
        section,
        _actionsWithFlagOn(section, segment),
      ),
      HomeSectionType.offerCarousel => _withItems(
        section,
        _offersForClient(section, clientInterests),
      ),
      _ => section,
    };
  }

  /// Accesos rápidos cuyo `flag` (si tienen) está encendido.
  List<Map<String, dynamic>> _actionsWithFlagOn(
    HomeSection section,
    String? segment,
  ) {
    return [
      for (final action in _items(section))
        if (_flagIsOn(action['flag'] as String?, segment)) action,
    ];
  }

  /// Ofertas que aplican al cliente: primero las de sus intereses, luego las
  /// generales (sin `interests`). Las dirigidas a otros intereses se ocultan.
  List<Map<String, dynamic>> _offersForClient(
    HomeSection section,
    List<String> clientInterests,
  ) {
    final forClient = <Map<String, dynamic>>[];
    final general = <Map<String, dynamic>>[];
    for (final offer in _items(section)) {
      final targets = _stringList(offer['interests']);
      if (targets.isEmpty) {
        general.add(offer);
      } else if (_sharesInterest(targets, clientInterests)) {
        forClient.add(offer);
      }
    }
    return [...forClient, ...general];
  }

  /// Respeta el `order` del banco. Dentro del mismo `order`, primero las
  /// secciones que coinciden con los intereses del cliente; si no, se
  /// conserva el orden en que llegaron.
  List<HomeSection> _sortByBankOrder(
    List<HomeSection> sections,
    List<String> clientInterests,
  ) {
    bool matches(HomeSection s) =>
        _sharesInterest(s.interests, clientInterests);

    final orders = {for (final s in sections) s.order}.toList()..sort();
    return [
      for (final order in orders) ...[
        for (final s in sections)
          if (s.order == order && matches(s)) s,
        for (final s in sections)
          if (s.order == order && !matches(s)) s,
      ],
    ];
  }

  bool _flagIsOn(String? flag, String? segment) =>
      flag == null || _flags.isEnabled(flag, segment: segment);

  static HomeSection? _withItems(
    HomeSection section,
    List<Map<String, dynamic>> items,
  ) {
    if (items.isEmpty) return null;
    return HomeSection(
      id: section.id,
      type: section.type,
      order: section.order,
      interests: section.interests,
      flag: section.flag,
      payload: {...section.payload, 'items': items},
    );
  }

  static List<Map<String, dynamic>> _items(HomeSection section) {
    final items = section.payload['items'];
    return items is List
        ? items.whereType<Map<String, dynamic>>().toList()
        : const [];
  }

  static bool _sharesInterest(List<String> a, List<String> b) =>
      a.any(b.contains);

  static List<String> _stringList(Object? value) =>
      value is List ? value.whereType<String>().toList() : const [];
}
