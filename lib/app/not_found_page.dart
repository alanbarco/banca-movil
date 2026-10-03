import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/routing/app_routes.dart';
import '../core/ui/theme.dart';
import '../core/ui/widgets/empty_view.dart';

/// Ruta inexistente (deep link viejo o mal formado).
class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const EmptyView(
            message: 'No encontramos esta pantalla.',
            icon: Icons.search_off,
          ),
          const SizedBox(height: AppSizes.spacing),
          FilledButton(
            onPressed: () => context.go(AppRoutes.home),
            child: const Text('Ir al inicio'),
          ),
        ],
      ),
    );
  }
}
