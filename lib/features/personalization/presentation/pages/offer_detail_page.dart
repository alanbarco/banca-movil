import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../../core/ui/theme.dart';
import '../../../../core/ui/widgets/empty_view.dart';
import '../../domain/entities/offer.dart';

/// Detalle de una oferta del inicio (`/offers/:offerId`, flag `offers`).
class OfferDetailPage extends StatelessWidget {
  const OfferDetailPage({required this.offer, super.key});

  static const notAvailable = 'Esta oferta ya no está disponible.';

  /// `null` si el banco ya no la publica para el segmento del cliente.
  final Offer? offer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final offer = this.offer;
    return Scaffold(
      appBar: AppBar(title: const Text('Oferta')),
      body: offer == null
          ? const EmptyView(
              message: notAvailable,
              icon: Icons.local_offer_outlined,
            )
          : ListView(
              padding: const EdgeInsets.all(AppSizes.spacing * 1.5),
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    offer.title,
                    style: theme.textTheme.headlineSmall,
                  ),
                ),
                const SizedBox(height: 12),
                Text(offer.description, style: theme.textTheme.bodyLarge),
                const SizedBox(height: AppSizes.spacing * 2),
                OutlinedButton(
                  onPressed: () => context.canPop()
                      ? context.pop()
                      : context.go(AppRoutes.home),
                  child: const Text('Volver al inicio'),
                ),
              ],
            ),
    );
  }
}
