import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/ui/theme.dart';
import '../../domain/entities/registration_data.dart';
import '../auth_texts.dart';
import '../bloc/onboarding_cubit.dart';
import 'auth_scaffold.dart';
import 'password_field.dart';

class CredentialsStep extends StatefulWidget {
  const CredentialsStep({required this.state, super.key});

  final OnboardingState state;

  @override
  State<CredentialsStep> createState() => _CredentialsStepState();
}

class _CredentialsStepState extends State<CredentialsStep> {
  late final _fullName = TextEditingController(text: widget.state.fullName);
  late final _email = TextEditingController(text: widget.state.email);
  late final _password = TextEditingController(text: widget.state.password);

  @override
  void didUpdateWidget(CredentialsStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Tras un error la contraseña se borra en el estado: reflejarlo.
    if (widget.state.password.isEmpty && _password.text.isNotEmpty) {
      _password.clear();
    }
  }

  @override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<OnboardingCubit>();
    final state = widget.state;
    final completing = state.completingProfile;
    String? errorFor(String field) {
      if (state.invalidField != field) return null;
      // Con formato válido, el rechazo del correo vino del servidor.
      final fromServer =
          field == 'email' && RegistrationRules.isValidEmail(state.email);
      return AuthTexts.fieldError(field, fromServer: fromServer);
    }

    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (completing) ...[
            const Text(
              'Tu acceso ya fue creado. Completa tus datos para abrir tu cuenta.',
            ),
            const SizedBox(height: AppSizes.spacing),
          ],
          TextField(
            controller: _fullName,
            textCapitalization: TextCapitalization.words,
            autofillHints: const [AutofillHints.name],
            textInputAction: TextInputAction.next,
            onChanged: (value) => cubit.updateCredentials(fullName: value),
            decoration: InputDecoration(
              labelText: 'Nombre completo',
              errorText: errorFor('fullName'),
            ),
          ),
          const SizedBox(height: AppSizes.spacing),
          TextField(
            controller: _email,
            readOnly: completing,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            autocorrect: false,
            textInputAction: TextInputAction.next,
            onChanged: (value) => cubit.updateCredentials(email: value),
            decoration: InputDecoration(
              labelText: 'Correo electrónico',
              errorText: errorFor('email'),
            ),
          ),
          if (!completing) ...[
            const SizedBox(height: AppSizes.spacing),
            PasswordField(
              controller: _password,
              isNewPassword: true,
              errorText: errorFor('password'),
              onChanged: (value) => cubit.updateCredentials(password: value),
            ),
            const SizedBox(height: 8),
            PasswordRequirements(password: state.password),
          ],
          if (state.failure case final failure?) ...[
            const SizedBox(height: AppSizes.spacing),
            AuthErrorBanner(message: AuthTexts.forFailure(failure)),
          ],
          const SizedBox(height: AppSizes.spacing * 1.5),
          FilledButton(
            onPressed: cubit.continueFromCredentials,
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
  }
}
