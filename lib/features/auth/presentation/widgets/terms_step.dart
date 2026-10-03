import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/ui/theme.dart';
import '../auth_texts.dart';
import '../bloc/onboarding_cubit.dart';
import 'auth_scaffold.dart';

class TermsStep extends StatelessWidget {
  const TermsStep({
    required this.state,
    required this.termsVersion,
    required this.termsUrl,
    super.key,
  });

  final OnboardingState state;
  final String termsVersion;
  final String termsUrl;

  Future<void> _openTerms() async {
    final uri = Uri.tryParse(termsUrl);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<OnboardingCubit>();
    final theme = Theme.of(context);
    final submitting = state.step == OnboardingStep.submitting;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Antes de abrir tu cuenta, lee y acepta los términos y condiciones '
          '(versión $termsVersion).',
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 8),
        if (termsUrl.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _openTerms,
              icon: const Icon(Icons.open_in_new),
              label: const Text('Leer términos y condiciones'),
            ),
          ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: state.termsAccepted,
          onChanged: submitting
              ? null
              : (value) => cubit.setTermsAccepted(accepted: value ?? false),
          title: const Text('Acepto los términos y condiciones'),
        ),
        // El motivo del botón deshabilitado siempre es visible (US1-2).
        if (!state.termsAccepted)
          Semantics(
            liveRegion: state.invalidField == 'terms',
            child: Text(
              AuthTexts.termsRequired,
              style: TextStyle(
                color: state.invalidField == 'terms'
                    ? theme.colorScheme.error
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        if (state.failure case final failure?) ...[
          const SizedBox(height: AppSizes.spacing),
          AuthErrorBanner(
            message: AuthTexts.forFailure(failure),
            onRetry: AuthTexts.isRetryable(failure) ? cubit.submit : null,
          ),
        ],
        const SizedBox(height: AppSizes.spacing * 1.5),
        SubmitButton(
          label: 'Abrir mi cuenta',
          loading: submitting,
          onPressed: state.termsAccepted ? cubit.submit : null,
        ),
      ],
    );
  }
}
