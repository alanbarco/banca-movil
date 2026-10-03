import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Usuario de Firebase Auth reducido a lo que la app necesita.
class AuthUser extends Equatable {
  const AuthUser({required this.uid, required this.email});

  final String uid;
  final String email;

  @override
  List<Object?> get props => [uid, email];
}

/// Envoltorio fino sobre Firebase Auth. Lanza `FirebaseAuthException`; la
/// traducción a `Failure` la hace el repositorio.
class FirebaseAuthDatasource {
  FirebaseAuthDatasource([FirebaseAuth? auth])
    : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  Stream<AuthUser?> authStateChanges() =>
      _auth.authStateChanges().map(_toAuthUser);

  AuthUser? get currentUser => _toAuthUser(_auth.currentUser);

  Future<AuthUser> signIn(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return _toAuthUser(credential.user)!;
  }

  Future<AuthUser> createUser(String email, String password) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    return _toAuthUser(credential.user)!;
  }

  Future<void> sendPasswordReset(String email) async {
    await _auth.setLanguageCode('es');
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> signOut() => _auth.signOut();

  static AuthUser? _toAuthUser(User? user) {
    if (user == null) return null;
    return AuthUser(uid: user.uid, email: user.email ?? '');
  }
}
