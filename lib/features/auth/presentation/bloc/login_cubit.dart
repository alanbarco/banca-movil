import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/observability/analytics_events.dart';
import '../../../../core/observability/observability_service.dart';
import '../../domain/usecases/sign_in.dart';

enum LoginStatus { idle, submitting, success, failure }

class LoginState extends Equatable {
  const LoginState({
    this.email = '',
    this.status = LoginStatus.idle,
    this.failure,
  });

  final String email;
  final LoginStatus status;
  final Failure? failure;

  bool get isSubmitting => status == LoginStatus.submitting;

  @override
  List<Object?> get props => [email, status, failure];
}

class LoginCubit extends Cubit<LoginState> {
  LoginCubit({
    required SignIn signIn,
    required ObservabilityService observability,
    String initialEmail = '',
  }) : _signIn = signIn,
       _observability = observability,
       super(LoginState(email: initialEmail));

  final SignIn _signIn;
  final ObservabilityService _observability;

  Future<void> submit({required String email, required String password}) async {
    if (state.isSubmitting) return;
    emit(LoginState(email: email, status: LoginStatus.submitting));

    final result = await _signIn(email: email, password: password);
    final failure = result.failureOrNull;
    if (failure == null) {
      await _observability.logEvent(AnalyticsEvents.loginSuccess);
      emit(LoginState(email: email, status: LoginStatus.success));
      return;
    }

    // Los campos vacíos se validan localmente: no son intentos de login.
    if (failure is! ValidationFailure) {
      await _observability.logEvent(AnalyticsEvents.loginFailure, {
        AnalyticsParams.reason: switch (failure) {
          UnauthorizedFailure() => 'invalid_credentials',
          NetworkFailure() || TimeoutFailure() => 'network',
          _ => 'other',
        },
      });
    }
    emit(
      LoginState(email: email, status: LoginStatus.failure, failure: failure),
    );
  }
}
