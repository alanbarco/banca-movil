import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../domain/usecases/send_password_reset.dart';

enum ForgotPasswordStatus { idle, submitting, sent, failure }

class ForgotPasswordState extends Equatable {
  const ForgotPasswordState({
    this.status = ForgotPasswordStatus.idle,
    this.failure,
  });

  final ForgotPasswordStatus status;
  final Failure? failure;

  @override
  List<Object?> get props => [status, failure];
}

/// La confirmación es la misma exista o no el correo (FR-006).
class ForgotPasswordCubit extends Cubit<ForgotPasswordState> {
  ForgotPasswordCubit(this._sendPasswordReset)
    : super(const ForgotPasswordState());

  final SendPasswordReset _sendPasswordReset;

  Future<void> submit(String email) async {
    if (state.status == ForgotPasswordStatus.submitting) return;
    emit(const ForgotPasswordState(status: ForgotPasswordStatus.submitting));
    final result = await _sendPasswordReset(email);
    emit(
      result.fold(
        (failure) => ForgotPasswordState(
          status: ForgotPasswordStatus.failure,
          failure: failure,
        ),
        (_) => const ForgotPasswordState(status: ForgotPasswordStatus.sent),
      ),
    );
  }
}
