import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../entities/interest.dart';
import '../entities/registration_data.dart';
import '../repositories/auth_repository.dart';

/// Cambia los intereses del cliente (FR-018); el inicio se adapta solo al
/// recibir el perfil actualizado.
class UpdateInterests {
  const UpdateInterests(this._repository);

  final AuthRepository _repository;

  Future<Result<void>> call(List<Interest> interests) {
    if (!RegistrationRules.isValidInterests(interests)) {
      return Future.value(const Err(Failure.validation('interests')));
    }
    return _repository.updateInterests(interests);
  }
}
