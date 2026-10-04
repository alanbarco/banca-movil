import 'package:equatable/equatable.dart';

import '../../../../core/sdui/home_section.dart';
import '../../../../core/sdui/home_section_parser.dart';

/// `home_layout` ya validado: secciones de cada segmento (FR-014).
class HomeLayout extends Equatable {
  const HomeLayout({this.segments = const {}});

  static const defaultSegment = HomeSectionParser.defaultSegment;

  final Map<String, HomeLayoutParseResult> segments;

  /// Layout del [segment] o, si no existe, el `default`.
  HomeLayoutParseResult? forSegment(String? segment) =>
      segments[segment] ?? segments[defaultSegment];

  @override
  List<Object?> get props => [segments];
}

/// Inicio listo para dibujar.
class ResolvedHome extends Equatable {
  const ResolvedHome({
    required this.sections,
    this.skipped = const [],
    this.usedFallback = false,
  });

  final List<HomeSection> sections;

  /// Secciones omitidas por inválidas o no soportadas (FR-016).
  final List<SkippedSection> skipped;

  /// `true` si se usó la configuración predeterminada local (FR-017).
  final bool usedFallback;

  @override
  List<Object?> get props => [sections, skipped, usedFallback];
}
