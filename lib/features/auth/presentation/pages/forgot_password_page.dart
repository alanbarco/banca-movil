import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/ui/theme.dart';
import '../auth_texts.dart';
import '../bloc/forgot_password_cubit.dart';
import '../widgets/auth_scaffold.dart';

/// Recuperación de contraseña. Requiere un [ForgotPasswordCubit].
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({this.initialEmail = '', super.key});

  final String initialEmail;

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  late final _email = TextEditingController(text: widget.initialEmail);

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _submit() => context.read<ForgotPasswordCubit>().submit(_email.text);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ForgotPasswordCubit, ForgotPasswordState>(
      builder: (context, state) {
        if (state.status == ForgotPasswordStatus.sent) {
          return AuthScaffold(
            title: 'Revisa tu correo',
            showBack: true,
            children: [
              Semantics(
                liveRegion: true,
                child: Text(
                  AuthTexts.resetSent,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              const SizedBox(height: AppSizes.spacing * 1.5),
              FilledButton(
                onPressed: () => context.go(AppRoutes.login),
                child: const Text('Volver a iniciar sesión'),
              ),
            ],
          );
        }

        final failure = state.failure;
        final invalidEmail =
            failure is ValidationFailure && failure.field == 'email';
        return AuthScaffold(
          title: 'Recupera tu contraseña',
          subtitle: 'Te enviaremos instrucciones a tu correo.',
          showBack: true,
          children: [
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              autocorrect: false,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'Correo electrónico',
                errorText: invalidEmail ? AuthTexts.fieldError('email') : null,
              ),
            ),
            if (failure != null && !invalidEmail) ...[
              const SizedBox(height: AppSizes.spacing),
              AuthErrorBanner(
                message: AuthTexts.forFailure(failure),
                onRetry: AuthTexts.isRetryable(failure) ? _submit : null,
              ),
            ],
            const SizedBox(height: AppSizes.spacing * 1.5),
            SubmitButton(
              label: 'Enviar instrucciones',
              loading: state.status == ForgotPasswordStatus.submitting,
              onPressed: _submit,
            ),
          ],
        );
      },
    );
  }
}
