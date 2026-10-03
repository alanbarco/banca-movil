import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../connectivity/connectivity_cubit.dart';

/// Banner global mientras no hay conexión (FR-029).
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  static const message = 'Sin conexión. Mostraremos tus datos guardados.';

  @override
  Widget build(BuildContext context) {
    final offline = context.select<ConnectivityCubit, bool>(
      (cubit) => !cubit.state.isOnline,
    );
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      child: offline ? const OfflineBannerContent() : const SizedBox.shrink(),
    );
  }
}

/// Contenido visual del banner, separado para poder usarlo sin el Cubit.
class OfflineBannerContent extends StatelessWidget {
  const OfflineBannerContent({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      liveRegion: true,
      label: OfflineBanner.message,
      excludeSemantics: true,
      child: Material(
        color: scheme.inverseSurface,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.cloud_off, size: 18, color: scheme.onInverseSurface),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    OfflineBanner.message,
                    style: TextStyle(color: scheme.onInverseSurface),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
