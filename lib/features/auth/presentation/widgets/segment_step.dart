import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/ui/theme.dart';
import '../../domain/entities/segment.dart';
import '../auth_texts.dart';
import '../bloc/onboarding_cubit.dart';

class SegmentStep extends StatelessWidget {
  const SegmentStep({required this.state, super.key});

  final OnboardingState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<OnboardingCubit>();
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final segment in Segment.values) ...[
          _SegmentCard(
            segment: segment,
            selected: state.segment == segment,
            onTap: () => cubit.selectSegment(segment),
          ),
          const SizedBox(height: 12),
        ],
        if (state.invalidField == 'segment')
          Semantics(
            liveRegion: true,
            child: Text(
              AuthTexts.fieldError('segment'),
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        const SizedBox(height: AppSizes.spacing),
        FilledButton(
          onPressed: cubit.continueFromProfile,
          child: const Text('Continuar'),
        ),
      ],
    );
  }
}

class _SegmentCard extends StatelessWidget {
  const _SegmentCard({
    required this.segment,
    required this.selected,
    required this.onTap,
  });

  final Segment segment;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      button: true,
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radius),
          side: BorderSide(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: ListTile(
          minVerticalPadding: 12,
          leading: Icon(segment.icon, color: scheme.primary),
          title: Text(segment.label),
          subtitle: Text(segment.description),
          trailing: Icon(
            selected ? Icons.radio_button_checked : Icons.radio_button_off,
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}
