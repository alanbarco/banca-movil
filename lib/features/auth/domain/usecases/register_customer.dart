import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../entities/registration_data.dart';
import '../repositories/auth_repository.dart';

/// Registra un cliente nuevo validando FR-001–FR-003 antes de ir a la red.
class RegisterCustomer {
  const RegisterCustomer(this._repository);

  final AuthRepository _repository;

  /// `true` si un intento anterior ya creó la cuenta y solo falta el perfil.
  bool get hasAuthAccount => _repository.hasAuthAccount;

  Future<Result<void>> call(
    RegistrationData data, {
    bool completingProfile = false,
  }) async {
    final failure = validate(data, requirePassword: !completingProfile);
    if (failure != null) return Err(failure);
    return completingProfile
        ? _repository.completeProfile(data)
        : _repository.register(data);
  }

  /// Primera regla incumplida, en el orden en que el cliente ve los campos.
  static Failure? validate(
    RegistrationData data, {
    bool requirePassword = true,
  }) {
    if (!RegistrationRules.isValidFullName(data.fullName)) {
      return const Failure.validation('fullName');
    }
    if (!RegistrationRules.isValidEmail(data.email)) {
      return const Failure.validation('email');
    }
    if (requirePassword && !PasswordPolicy.isValid(data.password)) {
      return const Failure.validation('password');
    }
    if (!RegistrationRules.isValidInterests(data.interests)) {
      return const Failure.validation('interests');
    }
    if (!data.termsAccepted || data.termsVersion.isEmpty) {
      return const Failure.validation('terms');
    }
    return null;
  }
}
