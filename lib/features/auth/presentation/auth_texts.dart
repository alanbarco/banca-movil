import 'package:flutter/material.dart';

import '../../../core/error/failure.dart';
import '../domain/entities/interest.dart';
import '../domain/entities/segment.dart';

extension SegmentTexts on Segment {
  String get label => switch (this) {
    Segment.student => 'Joven / estudiante',
    Segment.professional => 'Profesional',
    Segment.entrepreneur => 'Emprendedor',
  };

  String get description => switch (this) {
    Segment.student => 'Empiezo a manejar mi dinero y quiero ahorrar.',
    Segment.professional => 'Tengo ingresos estables y quiero hacerlos crecer.',
    Segment.entrepreneur => 'Tengo o estoy creando mi propio negocio.',
  };

  IconData get icon => switch (this) {
    Segment.student => Icons.school_outlined,
    Segment.professional => Icons.work_outline,
    Segment.entrepreneur => Icons.storefront_outlined,
  };
}

extension InterestTexts on Interest {
  String get label => switch (this) {
    Interest.savings => 'Ahorro',
    Interest.investment => 'Inversión',
    Interest.travel => 'Viajes',
    Interest.education => 'Educación',
    Interest.business => 'Emprendimiento',
  };

  IconData get icon => switch (this) {
    Interest.savings => Icons.savings_outlined,
    Interest.investment => Icons.trending_up,
    Interest.travel => Icons.flight_outlined,
    Interest.education => Icons.menu_book_outlined,
    Interest.business => Icons.business_center_outlined,
  };
}

/// Mensajes para el cliente. Ninguno revela si un correo existe (FR-006).
abstract final class AuthTexts {
  static const invalidCredentials = 'Correo o contraseña incorrectos.';
  static const network =
      'No pudimos conectarnos. Revisa tu conexión e inténtalo de nuevo.';
  static const generic = 'Ocurrió un problema. Inténtalo de nuevo.';
  static const tooManyAttempts =
      'Demasiados intentos. Espera unos minutos e inténtalo de nuevo.';
  static const termsRequired =
      'Debes aceptar los términos y condiciones para continuar.';
  static const resetSent =
      'Si el correo está registrado, te enviamos instrucciones para '
      'restablecer tu contraseña.';

  static String forFailure(Failure failure) => switch (failure) {
    UnauthorizedFailure() => invalidCredentials,
    NetworkFailure() || TimeoutFailure() => network,
    ServerFailure() => tooManyAttempts,
    _ => generic,
  };

  static bool isRetryable(Failure failure) =>
      failure is NetworkFailure || failure is TimeoutFailure;

  /// Mensaje junto al campo inválido.
  static String fieldError(String field, {bool fromServer = false}) {
    return switch (field) {
      'fullName' => 'Ingresa tu nombre completo (3 a 80 caracteres).',
      // En el registro el mensaje es específico (escenario US1-3); FR-006
      // solo aplica a login y recuperación.
      'email' when fromServer =>
        'Este correo ya tiene una cuenta. Inicia sesión o usa otro correo.',
      'email' => 'Ingresa un correo válido.',
      'password' => 'La contraseña no cumple los requisitos.',
      'segment' => 'Elige la opción que mejor te describe.',
      'interests' => 'Elige entre 1 y 5 intereses.',
      'terms' => termsRequired,
      _ => generic,
    };
  }
}
