import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../entities/registration_data.dart';
import '../repositories/auth_repository.dart';

class SendPasswordReset {
  const SendPasswordReset(this._repository);

  final AuthRepository _repository;

  Future<Result<void>> call(String email) {
    if (!RegistrationRules.isValidEmail(email)) {
      return Future.value(const Err(Failure.validation('email')));
    }
    return _repository.sendPasswordReset(email.trim());
  }
}
