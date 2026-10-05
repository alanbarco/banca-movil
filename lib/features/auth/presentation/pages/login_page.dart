import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/ui/theme.dart';
import '../auth_texts.dart';
import '../bloc/login_cubit.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/password_field.dart';

/// Inicio de sesión. Requiere un [LoginCubit] en el árbol.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late final TextEditingController _email;
  final _password = TextEditingController();

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(
      text: context.read<LoginCubit>().state.email,
    );
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    context.read<LoginCubit>().submit(
      email: _email.text,
      password: _password.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LoginCubit, LoginState>(
      builder: (context, state) {
        final failure = state.failure;
        final validationField = failure is ValidationFailure
            ? failure.field
            : null;
        return AuthScaffold(
          title: '¡Bienvenido!',
          subtitle: 'Ingresa a tu banca digital.',
          children: [
            AutofillGroup(
              child: Column(
                children: [
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    autocorrect: false,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Correo electrónico',
                      errorText: validationField == 'email'
                          ? 'Ingresa tu correo.'
                          : null,
                    ),
                  ),
                  const SizedBox(height: AppSizes.spacing),
                  PasswordField(
                    controller: _password,
                    errorText: validationField == 'password'
                        ? 'Ingresa tu contraseña.'
                        : null,
                    onSubmitted: (_) => _submit(),
                  ),
                ],
              ),
            ),
            if (failure != null && validationField == null) ...[
              const SizedBox(height: AppSizes.spacing),
              AuthErrorBanner(
                message: AuthTexts.forFailure(failure),
                onRetry: AuthTexts.isRetryable(failure) ? _submit : null,
              ),
            ],
            const SizedBox(height: AppSizes.spacing * 1.5),
            SubmitButton(
              label: 'Ingresar',
              loading: state.isBusy,
              onPressed: _submit,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: state.isBusy
                  ? null
                  : () => context.push(AppRoutes.forgotPassword),
              child: const Text('¿Olvidaste tu contraseña?'),
            ),
            const Divider(height: AppSizes.spacing * 2),
            OutlinedButton(
              onPressed: state.isBusy
                  ? null
                  : () => context.go(AppRoutes.register),
              child: const Text('Hazte cliente'),
            ),
          ],
        );
      },
    );
  }
}
