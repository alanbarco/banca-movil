import 'package:equatable/equatable.dart';

/// Tipos de sección que esta build sabe dibujar.
enum HomeSectionType {
  accountsSummary('accounts_summary'),
  banner('banner'),
  offerCarousel('offer_carousel'),
  quickActions('quick_actions'),
  tip('tip');

  const HomeSectionType(this.wireName);

  /// Valor de `type` en el JSON de `home_layout`.
  final String wireName;

  static HomeSectionType? fromWire(String value) {
    for (final type in values) {
      if (type.wireName == value) return type;
    }
    return null;
  }
}

/// Sección del inicio definida por el servidor (SDUI).
class HomeSection extends Equatable {
  const HomeSection({
    required this.id,
    required this.type,
    required this.order,
    this.interests = const [],
    this.flag,
    this.payload = const {},
  });

  final String id;
  final HomeSectionType type;
  final int order;

  /// Si no está vacío, la sección se prioriza (o filtra) por estos intereses.
  final List<String> interests;

  /// Clave de `feature_flags` que debe estar activa para mostrarla.
  final String? flag;

  /// Contenido ya validado según [type].
  final Map<String, dynamic> payload;

  @override
  List<Object?> get props => [id, type, order, interests, flag, payload];
}
