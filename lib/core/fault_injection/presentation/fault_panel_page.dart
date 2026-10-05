import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../observability/observability_service.dart';
import '../../ui/theme.dart';
import '../fault_config.dart';
import '../fault_injection_cubit.dart';

/// Panel de demo para degradar cada servicio en vivo (FR-032): sin conexión,
/// latencia o error. Solo existe en builds con `DEMO_TOOLS`.
class FaultPanelPage extends StatelessWidget {
  const FaultPanelPage({required this.cubit, this.observability, super.key});

  final FaultInjectionCubit cubit;

  /// Si está, se muestran los botones para probar Crashlytics.
  final ObservabilityService? observability;

  static const title = 'Simulador de fallos';
  static const reset = 'Restablecer todo';
  static const nonFatal = 'Registrar error no fatal';
  static const fatal = 'Provocar crash';
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
            if (observability case final observability?)
              _CrashCard(observability: observability),
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
                  // Solo texto: con ícono, cuatro segmentos no caben en un
                  // teléfono y las palabras se cortan.
                  ButtonSegment(
                    value: mode,
                    label: Text(
                      FaultPanelPage.modeLabel(mode),
                      maxLines: 1,
                      softWrap: false,
                    ),
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

/// Error provocado a propósito desde el simulador para ver el reporte en
/// Crashlytics. El texto no lleva datos del cliente.
class DemoCrash implements Exception {
  const DemoCrash(this.kind);

  final String kind;

  @override
  String toString() => 'DemoCrash: $kind (simulador de fallos)';
}

/// Provoca un error no fatal o un crash fatal. Crashlytics los envía al volver
/// a abrir la app; en debug solo con DEMO_TOOLS (ver `main.dart`).
class _CrashCard extends StatelessWidget {
  const _CrashCard({required this.observability});

  static const title = 'Crashlytics';
  static const hint = 'El reporte llega a la consola al volver a abrir la app.';

  final ObservabilityService observability;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.spacing),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(hint, style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => observability.recordError(
                const DemoCrash('error no fatal'),
                StackTrace.current,
                reason: 'demo_fault_panel',
              ),
              child: const Text(FaultPanelPage.nonFatal),
            ),
            const SizedBox(height: 8),
            // Sin capturar: lo recibe FlutterError.onError y Crashlytics lo
            // registra como fatal.
            FilledButton(
              onPressed: () => throw const DemoCrash('crash fatal'),
              child: const Text(FaultPanelPage.fatal),
            ),
          ],
        ),
      ),
    );
  }
}
