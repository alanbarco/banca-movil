import 'package:flutter/material.dart';

import '../../../../core/sdui/home_section.dart';
import '../../../../core/ui/theme.dart';
import '../sdui_navigation.dart';

/// Sección `banner`: título, subtítulo, imagen opcional y destino opcional.
class BannerSection extends StatelessWidget {
  const BannerSection({required this.section, super.key});

  final HomeSection section;

  /// `#RRGGBB` → color; cualquier otro valor → `null`.
  static Color? parseColor(Object? value) {
    if (value is! String) return null;
    final match = RegExp(r'^#([0-9a-fA-F]{6})$').firstMatch(value);
    if (match == null) return null;
    return Color(0xFF000000 | int.parse(match.group(1)!, radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final payload = section.payload;
    final theme = Theme.of(context);
    final background = parseColor(payload['color']) ?? AppColors.primary;
    final foreground =
        ThemeData.estimateBrightnessForColor(background) == Brightness.dark
        ? Colors.white
        : Colors.black;
    final route = payload['route'] as String?;
    final imageUrl = payload['imageUrl'] as String?;

    return Card(
      color: background,
      clipBehavior: Clip.antiAlias,
      // Un solo foco para el lector de pantalla: título, subtítulo y acción.
      child: MergeSemantics(
        child: Semantics(
          button: route != null,
          child: InkWell(
            onTap: route == null ? null : () => openSduiRoute(context, route),
            child: Padding(
              padding: const EdgeInsets.all(AppSizes.spacing),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          payload['title'] as String,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: foreground,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          payload['subtitle'] as String,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: foreground,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  ExcludeSemantics(
                    child: SizedBox.square(
                      dimension: 56,
                      child: imageUrl == null
                          ? _FallbackIcon(color: foreground)
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                // Imagen caída: ícono en su lugar (FR-016).
                                errorBuilder: (_, _, _) =>
                                    _FallbackIcon(color: foreground),
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FallbackIcon extends StatelessWidget {
  const _FallbackIcon({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) =>
      Icon(Icons.campaign_outlined, size: 40, color: color);
}
