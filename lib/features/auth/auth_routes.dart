import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../core/observability/observability_service.dart';
import '../../core/routing/app_routes.dart';
import 'data/datasources/onboarding_seed_datasource.dart';
import 'domain/usecases/register_customer.dart';
import 'domain/usecases/send_password_reset.dart';
import 'domain/usecases/sign_in.dart';
import 'presentation/bloc/auth_bloc.dart';
import 'presentation/bloc/forgot_password_cubit.dart';
import 'presentation/bloc/login_cubit.dart';
import 'presentation/bloc/onboarding_cubit.dart';
import 'presentation/pages/forgot_password_page.dart';
import 'presentation/pages/login_page.dart';
import 'presentation/pages/profile_page.dart';
import 'presentation/pages/register_page.dart';

final _getIt = GetIt.instance;

/// `/login`, `/register`, `/forgot-password` (fuera del shell).
List<RouteBase> authRoutes() => [
  GoRoute(
    path: AppRoutes.login,
    builder: (context, state) => BlocProvider(
      create: (_) => LoginCubit(
        signIn: _getIt<SignIn>(),
        observability: _getIt<ObservabilityService>(),
        initialEmail: _getIt<AuthBloc>().state.prefillEmail ?? '',
      ),
      child: const LoginPage(),
    ),
  ),
  GoRoute(
    path: AppRoutes.register,
    builder: (context, state) {
      final terms = _getIt<OnboardingSeedDatasource>().terms();
      return BlocProvider(
        create: (_) => OnboardingCubit(
          registerCustomer: _getIt<RegisterCustomer>(),
          observability: _getIt<ObservabilityService>(),
          termsVersion: terms.version,
          // Cuenta creada sin perfil: solo se completan los datos.
          pendingEmail: _getIt<AuthBloc>().state.pendingEmail,
        )..start(),
        child: RegisterPage(termsVersion: terms.version, termsUrl: terms.url),
      );
    },
  ),
  GoRoute(
    path: AppRoutes.forgotPassword,
    builder: (context, state) => BlocProvider(
      create: (_) => ForgotPasswordCubit(_getIt<SendPasswordReset>()),
      child: ForgotPasswordPage(
        initialEmail: _getIt<AuthBloc>().state.prefillEmail ?? '',
      ),
    ),
  ),
];

/// `/profile` (pestaña del shell).
List<RouteBase> authShellRoutes() => [
  GoRoute(
    path: AppRoutes.profile,
    builder: (context, state) => ProfilePage(authBloc: _getIt<AuthBloc>()),
  ),
];
