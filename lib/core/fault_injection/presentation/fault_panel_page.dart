import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../ui/theme.dart';
import '../fault_config.dart';
import '../fault_injection_cubit.dart';

/// Panel de demo para degradar cada servicio en vivo (FR-032): sin conexión,
/// latencia o error. Solo existe en builds con `DEMO_TOOLS`.
class FaultPanelPage extends StatelessWidget {
  const FaultPanelPage({required this.cubit, super.key});

  final FaultInjectionCubit cubit;

  static const title = 'Simulador de fallos';
  static const reset = 'Restablecer todo';
  static const hint =
      'Aplica en la siguiente lectura de cada servicio: vuelve a la pantalla '
      'o desliza hacia abajo para refrescar.';

  static String targetLabel(FaultTarget target) => switch (target) {
    FaultTarget.firestore => 'Cuentas y movimientos (Firestore)',
    FaultTarget.personalization => 'Inicio personalizado (Remote Config)',
    FaultTarget.fx => 'Divisas (API externa)',
  };

  static String modeLabel(FaultMode mode) => switch (mode) {
    FaultMode.none => 'Normal',
    FaultMode.offline => 'Sin red',
    FaultMode.latency => 'Lento',
    FaultMode.error => 'Error',
  };

  static IconData _modeIcon(FaultMode mode) => switch (mode) {
    FaultMode.none => Icons.check_circle_outline,
    FaultMode.offline => Icons.cloud_off_outlined,
    FaultMode.latency => Icons.hourglass_bottom,
    FaultMode.error => Icons.error_outline,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(title),
        actions: [
          IconButton(
            tooltip: reset,
            icon: const Icon(Icons.restart_alt),
            onPressed: cubit.reset,
          ),
        ],
      ),
      body: BlocBuilder<FaultInjectionCubit, FaultInjectionState>(
        bloc: cubit,
        builder: (context, state) => ListView(
          padding: const EdgeInsets.all(AppSizes.spacing),
          children: [
            Text(hint, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: AppSizes.spacing),
            for (final target in FaultTarget.values) ...[
              _TargetCard(
                target: target,
                config: state.configFor(target),
                onChanged: (mode, latencyMs) =>
                    cubit.setFault(target, mode, latencyMs: latencyMs),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _TargetCard extends StatelessWidget {
  const _TargetCard({
    required this.target,
    required this.config,
    required this.onChanged,
  });

  static const minLatencyMs = 500.0;
  static const maxLatencyMs = 8000.0;

  final FaultTarget target;
  final FaultConfig config;
  final void Function(FaultMode mode, int? latencyMs) onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final latency = config.latencyMs
        .clamp(minLatencyMs, maxLatencyMs)
        .toDouble();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.spacing),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              FaultPanelPage.targetLabel(target),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            SegmentedButton<FaultMode>(
              key: Key('fault_${target.name}'),
              showSelectedIcon: false,
              segments: [
                for (final mode in FaultMode.values)
                  ButtonSegment(
                    value: mode,
                    icon: Icon(FaultPanelPage._modeIcon(mode)),
                    label: Text(FaultPanelPage.modeLabel(mode)),
                  ),
              ],
              selected: {config.mode},
              onSelectionChanged: (selected) =>
                  onChanged(selected.single, null),
            ),
            if (config.mode == FaultMode.latency) ...[
              const SizedBox(height: 8),
              Text(
                'Latencia: ${(latency / 1000).toStringAsFixed(1)} s',
                style: theme.textTheme.bodyMedium,
              ),
              Slider(
                value: latency,
                min: minLatencyMs,
                max: maxLatencyMs,
                divisions: 15,
                label: '${(latency / 1000).toStringAsFixed(1)} s',
                onChanged: (value) =>
                    onChanged(FaultMode.latency, value.round()),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
