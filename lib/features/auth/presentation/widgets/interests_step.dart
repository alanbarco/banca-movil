import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/ui/theme.dart';
import '../../domain/entities/interest.dart';
import '../../domain/entities/registration_data.dart';
import '../auth_texts.dart';
import '../bloc/onboarding_cubit.dart';

class InterestsStep extends StatelessWidget {
  const InterestsStep({required this.state, super.key});

  final OnboardingState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<OnboardingCubit>();
    final theme = Theme.of(context);
    final selectedCount = state.interests.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Elige de ${RegistrationRules.interestsMin} a '
          '${RegistrationRules.interestsMax} temas '
          '($selectedCount seleccionados).',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSizes.spacing),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final interest in Interest.values)
              FilterChip(
                avatar: Icon(interest.icon, size: 18),
                label: Text(interest.label),
                selected: state.interests.contains(interest),
                onSelected: (_) => cubit.toggleInterest(interest),
              ),
          ],
        ),
        if (state.invalidField == 'interests') ...[
          const SizedBox(height: AppSizes.spacing),
          Semantics(
            liveRegion: true,
            child: Text(
              AuthTexts.fieldError('interests'),
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        ],
        const SizedBox(height: AppSizes.spacing * 1.5),
        FilledButton(
          onPressed: cubit.continueFromInterests,
          child: const Text('Continuar'),
        ),
      ],
    );
  }
}
