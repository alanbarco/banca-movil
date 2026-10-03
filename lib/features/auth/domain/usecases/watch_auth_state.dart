import '../entities/auth_session.dart';
import '../repositories/auth_repository.dart';

class WatchAuthState {
  const WatchAuthState(this._repository);

  final AuthRepository _repository;

  Stream<AuthSession> call() => _repository.session;
}
