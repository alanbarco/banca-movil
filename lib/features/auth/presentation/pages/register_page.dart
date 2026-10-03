import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../../core/ui/theme.dart';
import '../bloc/onboarding_cubit.dart';
import '../widgets/credentials_step.dart';
import '../widgets/interests_step.dart';
import '../widgets/segment_step.dart';
import '../widgets/terms_step.dart';

/// Onboarding por pasos. Requiere un [OnboardingCubit] en el árbol.
class RegisterPage extends StatelessWidget {
  const RegisterPage({
    required this.termsVersion,
    required this.termsUrl,
    super.key,
  });

  final String termsVersion;
  final String termsUrl;

  static String titleFor(OnboardingStep step) => switch (step) {
    OnboardingStep.credentials => 'Crea tu acceso',
    OnboardingStep.profile => '¿Qué te describe mejor?',
    OnboardingStep.interests => '¿Qué te interesa?',
    _ => 'Términos y condiciones',
  };

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OnboardingCubit, OnboardingState>(
      builder: (context, state) {
        final cubit = context.read<OnboardingCubit>();
        final isFirstStep = state.step == OnboardingStep.credentials;
        final busy =
            state.step == OnboardingStep.submitting ||
            state.step == OnboardingStep.done;

        void goBack() {
          if (isFirstStep) {
            context.go(AppRoutes.login);
          } else {
            cubit.back();
          }
        }

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && !busy) goBack();
          },
          child: Scaffold(
            appBar: AppBar(
              leading: IconButton(
                tooltip: isFirstStep ? 'Volver al inicio de sesión' : 'Atrás',
                icon: const Icon(Icons.arrow_back),
                onPressed: busy ? null : goBack,
              ),
              title: Text(
                'Paso ${state.stepNumber} de '
                '${OnboardingState.totalSteps}',
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(4),
                child: Semantics(
                  label:
                      'Progreso: paso ${state.stepNumber} de '
                      '${OnboardingState.totalSteps}',
                  child: LinearProgressIndicator(
                    value: state.stepNumber / OnboardingState.totalSteps,
                  ),
                ),
              ),
            ),
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSizes.spacing * 1.5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        state.step == OnboardingStep.done
                            ? '¡Tu cuenta está lista!'
                            : titleFor(state.step),
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    const SizedBox(height: AppSizes.spacing * 1.5),
                    switch (state.step) {
                      OnboardingStep.credentials => CredentialsStep(
                        state: state,
                      ),
                      OnboardingStep.profile => SegmentStep(state: state),
                      OnboardingStep.interests => InterestsStep(state: state),
                      OnboardingStep.terms ||
                      OnboardingStep.submitting => TermsStep(
                        state: state,
                        termsVersion: termsVersion,
                        termsUrl: termsUrl,
                      ),
                      // El router lleva al inicio en cuanto el perfil existe.
                      OnboardingStep.done => const Center(
                        child: CircularProgressIndicator(),
                      ),
                    },
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
