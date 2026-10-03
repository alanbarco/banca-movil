import 'dart:async';

import 'package:bi_app/core/error/failure.dart';
import 'package:bi_app/core/error/result.dart';
import 'package:bi_app/core/observability/analytics_events.dart';
import 'package:bi_app/features/auth/domain/entities/interest.dart';
import 'package:bi_app/features/auth/domain/entities/registration_data.dart';
import 'package:bi_app/features/auth/domain/entities/segment.dart';
import 'package:bi_app/features/auth/domain/usecases/register_customer.dart';
import 'package:bi_app/features/auth/presentation/bloc/onboarding_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fake_observability.dart';
import '../../auth_fixtures.dart';

class _MockRegister extends Mock implements RegisterCustomer {}

void main() {
  late _MockRegister register;
  late FakeObservabilityService observability;
  late OnboardingCubit cubit;

  setUpAll(() => registerFallbackValue(validRegistration));

  setUp(() {
    register = _MockRegister();
    observability = FakeObservabilityService();
    when(() => register.hasAuthAccount).thenReturn(false);
    when(
      () => register(any(), completingProfile: any(named: 'completingProfile')),
    ).thenAnswer((_) async => const Success(null));
    cubit = OnboardingCubit(
      registerCustomer: register,
      observability: observability,
      termsVersion: '2026-10',
    );
  });

  tearDown(() async {
    if (!cubit.isClosed) await cubit.close();
  });

  List<String?> viewedSteps() => observability
      .named(AnalyticsEvents.onboardingStepViewed)
      .map((e) => e.parameters[AnalyticsParams.step] as String?)
      .toList();

  /// Lleva el flujo hasta el paso de términos con datos válidos.
  void fillUntilTerms() {
    cubit
      ..start()
      ..updateCredentials(
        fullName: 'Ana Pérez',
        email: 'ana@bi.test',
        password: 'secreta123',
      )
      ..continueFromCredentials()
      ..selectSegment(Segment.student)
      ..continueFromProfile()
      ..toggleInterest(Interest.education)
      ..toggleInterest(Interest.savings)
      ..continueFromInterests();
  }

  test('avanza por los pasos y registra cada vista', () {
    fillUntilTerms();

    expect(cubit.state.step, OnboardingStep.terms);
    expect(cubit.state.stepNumber, 4);
    expect(viewedSteps(), ['credentials', 'profile', 'interests', 'terms']);
  });

  test('no avanza con datos inválidos y marca el campo', () {
    cubit
      ..updateCredentials(fullName: 'Ana Pérez', email: 'ana@', password: 'x')
      ..continueFromCredentials();
    expect(cubit.state.step, OnboardingStep.credentials);
    expect(cubit.state.invalidField, 'email');

    cubit
      ..updateCredentials(email: 'ana@bi.test')
      ..continueFromCredentials();
    expect(cubit.state.invalidField, 'password');

    cubit
      ..updateCredentials(password: 'secreta123')
      ..continueFromCredentials()
      ..continueFromProfile();
    expect(cubit.state.step, OnboardingStep.profile);
    expect(cubit.state.invalidField, 'segment');

    cubit
      ..selectSegment(Segment.professional)
      ..continueFromProfile()
      ..continueFromInterests();
    expect(cubit.state.step, OnboardingStep.interests);
    expect(cubit.state.invalidField, 'interests');
  });

  test('permite como máximo 5 intereses y quitarlos', () {
    for (final interest in Interest.values) {
      cubit.toggleInterest(interest);
    }
    expect(cubit.state.interests, hasLength(5));

    cubit.toggleInterest(Interest.travel);
    expect(cubit.state.interests, isNot(contains(Interest.travel)));
  });

  test('no envía sin aceptar los términos', () async {
    fillUntilTerms();

    await cubit.submit();

    expect(cubit.state.step, OnboardingStep.terms);
    expect(cubit.state.invalidField, 'terms');
    verifyNever(
      () => register(any(), completingProfile: any(named: 'completingProfile')),
    );
  });

  test('registro exitoso: done y onboarding_completed', () async {
    fillUntilTerms();
    cubit.setTermsAccepted(accepted: true);

    await cubit.submit();

    expect(cubit.state.step, OnboardingStep.done);
    final data =
        verify(
              () => register(captureAny(), completingProfile: false),
            ).captured.single
            as RegistrationData;
    expect(data, validRegistration);
    expect(data.password, 'secreta123');
    final completed = observability.named(AnalyticsEvents.onboardingCompleted);
    expect(completed.single.parameters, {'segment': 'student'});
  });

  test('ignora el doble envío', () async {
    final pending = Completer<Result<void>>();
    when(
      () => register(any(), completingProfile: any(named: 'completingProfile')),
    ).thenAnswer((_) => pending.future);
    fillUntilTerms();
    cubit.setTermsAccepted(accepted: true);

    final first = cubit.submit();
    await cubit.submit();
    pending.complete(const Success(null));
    await first;

    verify(
      () => register(any(), completingProfile: any(named: 'completingProfile')),
    ).called(1);
  });

  test(
    'error de red sin cuenta creada: conserva datos salvo la contraseña',
    () async {
      when(
        () =>
            register(any(), completingProfile: any(named: 'completingProfile')),
      ).thenAnswer((_) async => const Err(Failure.network()));
      fillUntilTerms();
      cubit.setTermsAccepted(accepted: true);

      await cubit.submit();

      final state = cubit.state;
      expect(state.step, OnboardingStep.credentials);
      expect(state.failure, const Failure.network());
      expect(state.password, isEmpty);
      expect(state.fullName, 'Ana Pérez');
      expect(state.email, 'ana@bi.test');
      expect(state.segment, Segment.student);
      expect(state.interests, [Interest.education, Interest.savings]);
      expect(state.termsAccepted, isTrue);
    },
  );

  test(
    'error tras crear la cuenta: reintenta solo completando el perfil',
    () async {
      when(() => register.hasAuthAccount).thenReturn(true);
      when(
        () => register(any(), completingProfile: false),
      ).thenAnswer((_) async => const Err(Failure.timeout()));
      fillUntilTerms();
      cubit.setTermsAccepted(accepted: true);

      await cubit.submit();
      expect(cubit.state.step, OnboardingStep.terms);
      expect(cubit.state.completingProfile, isTrue);

      await cubit.submit();
      verify(() => register(any(), completingProfile: true)).called(1);
      expect(cubit.state.step, OnboardingStep.done);
    },
  );

  test('correo ya registrado vuelve al paso de credenciales', () async {
    when(
      () => register(any(), completingProfile: any(named: 'completingProfile')),
    ).thenAnswer((_) async => const Err(Failure.validation('email')));
    fillUntilTerms();
    cubit.setTermsAccepted(accepted: true);

    await cubit.submit();

    expect(cubit.state.step, OnboardingStep.credentials);
    expect(cubit.state.invalidField, 'email');
    expect(cubit.state.failure, isNull);
  });

  test('back retrocede un paso y no sale del primero', () {
    fillUntilTerms();

    cubit.back();
    expect(cubit.state.step, OnboardingStep.interests);
    cubit
      ..back()
      ..back()
      ..back();
    expect(cubit.state.step, OnboardingStep.credentials);
  });

  test('perfil pendiente: correo fijo y sin contraseña', () {
    final completing =
        OnboardingCubit(
            registerCustomer: register,
            observability: observability,
            termsVersion: '2026-10',
            pendingEmail: 'ana@bi.test',
          )
          ..updateCredentials(fullName: 'Ana Pérez', email: 'otro@bi.test')
          ..continueFromCredentials();

    expect(completing.state.email, 'ana@bi.test');
    expect(completing.state.step, OnboardingStep.profile);
    unawaited(completing.close());
  });

  test('cerrar antes de terminar registra onboarding_abandoned', () async {
    fillUntilTerms();

    await cubit.close();

    final abandoned = observability.named(AnalyticsEvents.onboardingAbandoned);
    expect(abandoned.single.parameters, {'last_step': 'terms'});
  });

  test('cerrar tras terminar no es abandono', () async {
    fillUntilTerms();
    cubit.setTermsAccepted(accepted: true);
    await cubit.submit();

    await cubit.close();

    expect(observability.named(AnalyticsEvents.onboardingAbandoned), isEmpty);
  });
}
