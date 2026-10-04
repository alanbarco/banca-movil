import 'package:flutter/material.dart';

import '../../../../core/sdui/home_section.dart';
import '../../../../core/ui/theme.dart';
import '../../domain/entities/offer.dart';
import '../sdui_navigation.dart';

/// Sección `offer_carousel`: ofertas en scroll horizontal (ya filtradas y
/// ordenadas por intereses en `ResolveHomeLayout`).
class OfferCarouselSection extends StatelessWidget {
  const OfferCarouselSection({required this.section, super.key});

  static const title = 'Ofertas para ti';
  static const cardWidth = 260.0;

  final HomeSection section;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = section.payload['items'] as List;
    final offers = [
      for (final item in items)
        if (Offer.fromPayload(item) case final offer?)
          (offer: offer, route: (item as Map)['route'] as String?),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(title, style: theme.textTheme.titleLarge),
        ),
        const SizedBox(height: 8),
        // Altura flexible: crece con el tamaño de texto del sistema.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (index, entry) in offers.indexed) ...[
                  if (index > 0) const SizedBox(width: 12),
                  SizedBox(
                    width: cardWidth,
                    child: _OfferCard(offer: entry.offer, route: entry.route),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({required this.offer, this.route});

  final Offer offer;
  final String? route;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: MergeSemantics(
        child: InkWell(
          onTap: route == null ? null : () => openSduiRoute(context, route),
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.spacing),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(offer.title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Expanded(
                  child: Text(
                    offer.description,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                if (route != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Ver oferta',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
