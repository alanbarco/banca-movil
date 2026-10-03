import 'package:flutter/material.dart';

import '../theme.dart';

/// Bloque gris de carga. Es estático a propósito: sin animaciones infinitas
/// que molesten a lectores de pantalla o a los tests.
class Skeleton extends StatelessWidget {
  const Skeleton({this.width, this.height = 16, this.radius = 8, super.key});

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

/// Lista de placeholders con una única etiqueta accesible "Cargando".
class SkeletonList extends StatelessWidget {
  const SkeletonList({
    this.itemCount = 4,
    this.itemHeight = 64,
    this.semanticsLabel = 'Cargando',
    super.key,
  });

  final int itemCount;
  final double itemHeight;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      liveRegion: true,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSizes.spacing),
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: itemCount,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, _) => Skeleton(height: itemHeight, radius: 12),
      ),
    );
  }
}
