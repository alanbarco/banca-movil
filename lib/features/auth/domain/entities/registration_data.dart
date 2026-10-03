import 'package:equatable/equatable.dart';

import 'interest.dart';
import 'segment.dart';

/// Datos capturados en el onboarding.
class RegistrationData extends Equatable {
  const RegistrationData({
    required this.fullName,
    required this.email,
    required this.password,
    required this.segment,
    required this.interests,
    required this.termsAccepted,
    required this.termsVersion,
  });

  final String fullName;
  final String email;

  /// Vacía al completar el perfil de una cuenta ya creada.
  final String password;
  final Segment segment;
  final List<Interest> interests;
  final bool termsAccepted;
  final String termsVersion;

  // La contraseña no participa de la igualdad ni puede filtrarse en logs.
  @override
  List<Object?> get props => [
    fullName,
    email,
    segment,
    interests,
    termsAccepted,
    termsVersion,
  ];
}

/// Reglas de validación de los datos de registro (FR-001–FR-003).
///
/// Coinciden con las Security Rules (`firebase/firestore.rules`).
abstract final class RegistrationRules {
  static const fullNameMin = 3;
  static const fullNameMax = 80;
  static const interestsMin = 1;
  static const interestsMax = 5;

  static final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  static bool isValidFullName(String value) {
    final length = value.trim().length;
    return length >= fullNameMin && length <= fullNameMax;
  }

  static bool isValidEmail(String value) => _email.hasMatch(value.trim());

  static bool isValidInterests(List<Interest> interests) =>
      interests.length >= interestsMin &&
      interests.length <= interestsMax &&
      interests.toSet().length == interests.length;
}

/// Política de contraseñas (FR-002): al menos 8 caracteres, letras y números.
abstract final class PasswordPolicy {
  static const minLength = 8;

  static final _letter = RegExp(r'[A-Za-zÁÉÍÓÚÜÑáéíóúüñ]');
  static final _digit = RegExp(r'\d');

  static bool hasMinLength(String password) => password.length >= minLength;

  static bool hasLetter(String password) => _letter.hasMatch(password);

  static bool hasDigit(String password) => _digit.hasMatch(password);

  static bool isValid(String password) =>
      hasMinLength(password) && hasLetter(password) && hasDigit(password);
}
