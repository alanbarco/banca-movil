import '../../../../core/sdui/home_section.dart';
import '../entities/home_layout.dart';
import '../entities/offer.dart';
import '../repositories/home_layout_repository.dart';

/// Busca una oferta del layout vigente del segmento (`/offers/:offerId`).
class FindOffer {
  const FindOffer(this._repository);

  final HomeLayoutRepository _repository;

  /// `null` si el banco ya no la publica para ese segmento.
  Offer? call(String offerId, {required String? segment}) {
    final layout = _repository.current ?? _repository.localDefaults;
    return _find(layout, offerId, segment);
  }

  static Offer? _find(HomeLayout layout, String offerId, String? segment) {
    final sections = layout.forSegment(segment)?.sections ?? const [];
    for (final section in sections) {
      if (section.type != HomeSectionType.offerCarousel) continue;
      final items = section.payload['items'];
      if (items is! List) continue;
      for (final item in items) {
        final offer = Offer.fromPayload(item);
        if (offer?.id == offerId) return offer;
      }
    }
    return null;
  }
}
