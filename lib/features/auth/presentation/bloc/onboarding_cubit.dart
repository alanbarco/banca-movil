import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/observability/analytics_events.dart';
import '../../../../core/observability/observability_service.dart';
import '../../domain/entities/interest.dart';
import '../../domain/entities/registration_data.dart';
import '../../domain/entities/segment.dart';
import '../../domain/usecases/register_customer.dart';

enum OnboardingStep { credentials, profile, interests, terms, submitting, done }

class OnboardingState extends Equatable {
  const OnboardingState({
    this.step = OnboardingStep.credentials,
    this.fullName = '',
    this.email = '',
    this.password = '',
    this.segment,
    this.interests = const [],
    this.termsAccepted = false,
    this.completingProfile = false,
    this.invalidField,
    this.failure,
  });

  final OnboardingStep step;
  final String fullName;
  final String email;
  final String password;
  final Segment? segment;
  final List<Interest> interests;
  final bool termsAccepted;

  /// La cuenta de Auth ya existe: solo falta el perfil (sin contraseña).
  final bool completingProfile;

  /// Campo a resaltar (`fullName`, `email`, `password`, `segment`,
  /// `interests`, `terms`).
  final String? invalidField;

  /// Falla del último envío (red, servidor…), para el aviso general.
  final Failure? failure;

  /// Pasos visibles para el indicador de progreso (1..4).
  int get stepNumber => switch (step) {
    OnboardingStep.credentials => 1,
    OnboardingStep.profile => 2,
    OnboardingStep.interests => 3,
    _ => 4,
  };

  static const totalSteps = 4;

  OnboardingState copyWith({
    OnboardingStep? step,
    String? fullName,
    String? email,
    String? password,
    Segment? segment,
    List<Interest>? interests,
    bool? termsAccepted,
    bool? completingProfile,
    String? invalidField,
    Failure? failure,
    bool clearErrors = false,
  }) {
    return OnboardingState(
      step: step ?? this.step,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      password: password ?? this.password,
      segment: segment ?? this.segment,
      interests: interests ?? this.interests,
      termsAccepted: termsAccepted ?? this.termsAccepted,
      completingProfile: completingProfile ?? this.completingProfile,
      invalidField: clearErrors ? null : invalidField ?? this.invalidField,
      failure: clearErrors ? null : failure ?? this.failure,
    );
  }

  @override
  List<Object?> get props => [
    step,
    fullName,
    email,
    password,
    segment,
    interests,
    termsAccepted,
    completingProfile,
    invalidField,
    failure,
  ];
}

/// Flujo `credentials → profile → interests → terms → submitting → done`.
class OnboardingCubit extends Cubit<OnboardingState> {
  OnboardingCubit({
    required RegisterCustomer registerCustomer,
    required ObservabilityService observability,
    required this.termsVersion,
    String? pendingEmail,
  }) : _register = registerCustomer,
       _observability = observability,
       super(
         OnboardingState(
           email: pendingEmail ?? '',
           completingProfile: pendingEmail != null,
         ),
       );

  final RegisterCustomer _register;
  final ObservabilityService _observability;
  final String termsVersion;

  /// Registra la vista del paso inicial.
  void start() => _logStep(state.step);

  void updateCredentials({String? fullName, String? email, String? password}) {
    emit(
      state.copyWith(
        fullName: fullName,
        email: state.completingProfile ? null : email,
        password: password,
        clearErrors: true,
      ),
    );
  }

  void continueFromCredentials() {
    final field = _firstInvalidCredential();
    if (field != null) {
      emit(state.copyWith(invalidField: field));
      return;
    }
    _goTo(OnboardingStep.profile);
  }

  void selectSegment(Segment segment) {
    emit(state.copyWith(segment: segment, clearErrors: true));
  }

  void continueFromProfile() {
    if (state.segment == null) {
      emit(state.copyWith(invalidField: 'segment'));
      return;
    }
    _goTo(OnboardingStep.interests);
  }

  /// Agrega o quita un interés; ignora más de 5.
  void toggleInterest(Interest interest) {
    final current = state.interests;
    final List<Interest> next;
    if (current.contains(interest)) {
      next = [...current]..remove(interest);
    } else if (current.length < RegistrationRules.interestsMax) {
      next = [...current, interest];
    } else {
      return;
    }
    emit(state.copyWith(interests: next, clearErrors: true));
  }

  void continueFromInterests() {
    if (!RegistrationRules.isValidInterests(state.interests)) {
      emit(state.copyWith(invalidField: 'interests'));
      return;
    }
    _goTo(OnboardingStep.terms);
  }

  void setTermsAccepted({required bool accepted}) {
    emit(state.copyWith(termsAccepted: accepted, clearErrors: true));
  }

  void back() {
    final previous = switch (state.step) {
      OnboardingStep.profile => OnboardingStep.credentials,
      OnboardingStep.interests => OnboardingStep.profile,
      OnboardingStep.terms => OnboardingStep.interests,
      _ => null,
    };
    if (previous != null) _goTo(previous);
  }

  Future<void> submit() async {
    if (state.step == OnboardingStep.submitting ||
        state.step == OnboardingStep.done) {
      return;
    }
    if (!state.termsAccepted) {
      emit(state.copyWith(invalidField: 'terms'));
      return;
    }
    final segment = state.segment;
    if (segment == null) {
      _goTo(OnboardingStep.profile, invalidField: 'segment');
      return;
    }

    _goTo(OnboardingStep.submitting);
    final result = await _register(
      RegistrationData(
        fullName: state.fullName,
        email: state.email,
        password: state.password,
        segment: segment,
        interests: state.interests,
        termsAccepted: state.termsAccepted,
        termsVersion: termsVersion,
      ),
      completingProfile: state.completingProfile,
    );
    if (isClosed) return;

    final failure = result.failureOrNull;
    if (failure == null) {
      _goTo(OnboardingStep.done);
      unawaited(
        _observability.logEvent(AnalyticsEvents.onboardingCompleted, {
          AnalyticsParams.segment: segment.wireName,
        }),
      );
      return;
    }
    _onFailure(failure);
  }

  void _onFailure(Failure failure) {
    // Si la cuenta ya se creó, el reintento solo completa el perfil.
    final completing = state.completingProfile || _register.hasAuthAccount;
    if (failure case ValidationFailure(:final field)) {
      _goTo(
        _stepFor(field),
        invalidField: field,
        password: '',
        completingProfile: completing,
      );
      return;
    }
    // Se conservan todos los datos salvo la contraseña (FR-031); si aún hace
    // falta, se vuelve a pedir.
    _goTo(
      completing ? OnboardingStep.terms : OnboardingStep.credentials,
      failure: failure,
      password: '',
      completingProfile: completing,
    );
  }

  static OnboardingStep _stepFor(String field) => switch (field) {
    'segment' => OnboardingStep.profile,
    'interests' => OnboardingStep.interests,
    'terms' => OnboardingStep.terms,
    _ => OnboardingStep.credentials,
  };

  String? _firstInvalidCredential() {
    if (!RegistrationRules.isValidFullName(state.fullName)) return 'fullName';
    if (!RegistrationRules.isValidEmail(state.email)) return 'email';
    if (!state.completingProfile && !PasswordPolicy.isValid(state.password)) {
      return 'password';
    }
    return null;
  }

  void _goTo(
    OnboardingStep step, {
    String? invalidField,
    Failure? failure,
    String? password,
    bool? completingProfile,
  }) {
    final changed = step != state.step;
    emit(
      OnboardingState(
        step: step,
        fullName: state.fullName,
        email: state.email,
        password: password ?? state.password,
        segment: state.segment,
        interests: state.interests,
        termsAccepted: state.termsAccepted,
        completingProfile: completingProfile ?? state.completingProfile,
        invalidField: invalidField,
        failure: failure,
      ),
    );
    if (changed) _logStep(step);
  }

  void _logStep(OnboardingStep step) {
    if (step == OnboardingStep.submitting || step == OnboardingStep.done) {
      return;
    }
    unawaited(
      _observability.logEvent(AnalyticsEvents.onboardingStepViewed, {
        AnalyticsParams.step: step.name,
      }),
    );
  }

  /// Salir antes de terminar cuenta como abandono (FR-035).
  @override
  Future<void> close() async {
    if (state.step != OnboardingStep.done) {
      await _observability.logEvent(AnalyticsEvents.onboardingAbandoned, {
        AnalyticsParams.lastStep: state.step.name,
      });
    }
    return super.close();
  }
}
