import '../../../../core/sdui/home_section_parser.dart';
import '../../domain/entities/home_layout.dart';

/// JSON de `home_layout` → [HomeLayout]. Un segmento mal formado se ignora
/// sin afectar a los demás; un parámetro inválido da un layout vacío (el caso
/// de uso cae a los defaults locales).
abstract final class HomeLayoutModel {
  static const _parser = HomeSectionParser();

  static HomeLayout fromJson(Map<String, dynamic> json) {
    final segments = json['segments'];
    if (segments is! Map<String, dynamic>) return const HomeLayout();
    return HomeLayout(
      segments: {
        for (final entry in segments.entries)
          if (entry.value case {'sections': final List<dynamic> sections})
            entry.key: _parser.parseSections(sections),
      },
    );
  }
}
