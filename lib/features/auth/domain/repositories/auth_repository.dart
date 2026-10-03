import '../../../../core/error/result.dart';
import '../entities/auth_session.dart';
import '../entities/interest.dart';
import '../entities/registration_data.dart';
import '../entities/user_profile.dart';

abstract interface class AuthRepository {
  /// Emite la sesión vigente al suscribirse y luego cada cambio.
  Stream<AuthSession> get session;

  AuthSession? get currentSession;

  /// `true` si ya existe la cuenta en Firebase Auth (aunque falte el perfil).
  bool get hasAuthAccount;

  Future<Result<void>> signIn({
    required String email,
    required String password,
  });

  /// Crea la cuenta y, en un único batch, el perfil, la cuenta bancaria y los
  /// movimientos de ejemplo.
  Future<Result<void>> register(RegistrationData data);

  /// Reintenta el aprovisionamiento para un usuario autenticado sin perfil.
  Future<Result<void>> completeProfile(RegistrationData data);

  Future<Result<void>> signOut();

  /// Nunca revela si el correo existe (FR-006).
  Future<Result<void>> sendPasswordReset(String email);

  Stream<UserProfile?> watchProfile();

  Future<Result<void>> updateInterests(List<Interest> interests);

  Future<Result<void>> updateNotificationsEnabled({required bool enabled});
}
