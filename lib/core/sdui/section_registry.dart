import 'package:flutter/widgets.dart';

import 'home_section.dart';

typedef SectionBuilder =
    Widget Function(BuildContext context, HomeSection section);

/// Registro tipo → widget. Cada feature registra sus secciones desde su
/// módulo; `core` no conoce las implementaciones.
class SectionRegistry {
  final Map<HomeSectionType, SectionBuilder> _builders = {};

  void register(HomeSectionType type, SectionBuilder builder) {
    _builders[type] = builder;
  }

  bool isRegistered(HomeSectionType type) => _builders.containsKey(type);

  /// `null` si ninguna feature registró el tipo; el llamador la omite.
  Widget? build(BuildContext context, HomeSection section) {
    return _builders[section.type]?.call(context, section);
  }
}
