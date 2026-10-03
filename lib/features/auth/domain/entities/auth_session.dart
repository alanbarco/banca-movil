import 'package:equatable/equatable.dart';

import 'user_profile.dart';

/// Estado de la sesión combinando Firebase Auth y el perfil en Firestore.
sealed class AuthSession extends Equatable {
  const AuthSession();
}

final class SignedOutSession extends AuthSession {
  const SignedOutSession();

  @override
  List<Object?> get props => const [];
}

/// Autenticado pero sin perfil: el aprovisionamiento no llegó a completarse.
final class ProfileMissingSession extends AuthSession {
  const ProfileMissingSession({required this.uid, required this.email});

  final String uid;
  final String email;

  @override
  List<Object?> get props => [uid, email];
}

final class ActiveSession extends AuthSession {
  const ActiveSession(this.profile);

  final UserProfile profile;

  @override
  List<Object?> get props => [profile];
}
