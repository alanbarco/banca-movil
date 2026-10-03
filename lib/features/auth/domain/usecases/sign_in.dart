import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../repositories/auth_repository.dart';

class SignIn {
  const SignIn(this._repository);

  final AuthRepository _repository;

  Future<Result<void>> call({required String email, required String password}) {
    if (email.trim().isEmpty) {
      return Future.value(const Err(Failure.validation('email')));
    }
    if (password.isEmpty) {
      return Future.value(const Err(Failure.validation('password')));
    }
    return _repository.signIn(email: email.trim(), password: password);
  }
}
