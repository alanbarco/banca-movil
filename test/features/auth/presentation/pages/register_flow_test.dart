import 'package:bi_app/core/error/failure.dart';
import 'package:bi_app/core/error/result.dart';
import 'package:bi_app/core/observability/observability_service.dart';
import 'package:bi_app/features/auth/domain/usecases/register_customer.dart';
import 'package:bi_app/features/auth/presentation/auth_texts.dart';
import 'package:bi_app/features/auth/presentation/bloc/onboarding_cubit.dart';
import 'package:bi_app/features/auth/presentation/pages/register_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../auth_fixtures.dart';

class _MockRegister extends Mock implements RegisterCustomer {}

void main() {
  late _MockRegister register;
  late OnboardingCubit cubit;

  setUpAll(() => registerFallbackValue(validRegistration));

  setUp(() {
    register = _MockRegister();
    when(() => register.hasAuthAccount).thenReturn(false);
    cubit = OnboardingCubit(
      registerCustomer: register,
      observability: const NoopObservabilityService(),
      termsVersion: '2026-10',
    );
  });

  tearDown(() => cubit.close());

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: cubit,
          child: const RegisterPage(termsVersion: '2026-10', termsUrl: ''),
        ),
      ),
    );
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    final finder = find.text(text);
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pump();
  }

  Future<void> completeUntilTerms(WidgetTester tester) async {
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Ana Pérez');
    await tester.enterText(fields.at(1), 'ana@bi.test');
    await tester.enterText(fields.at(2), 'secreta123');
    await tapText(tester, 'Continuar');

    expect(find.text('Paso 2 de 4'), findsOneWidget);
    await tapText(tester, 'Joven / estudiante');
    await tapText(tester, 'Continuar');

    expect(find.text('Paso 3 de 4'), findsOneWidget);
    await tapText(tester, 'Educación');
    await tapText(tester, 'Continuar');

    expect(find.text('Paso 4 de 4'), findsOneWidget);
  }

  FilledButton openAccountButton(WidgetTester tester) => tester.widget(
    find.ancestor(
      of: find.text('Abrir mi cuenta'),
      matching: find.byType(FilledButton),
    ),
  );

  testWidgets('muestra los requisitos de contraseña mientras se escribe', (
    tester,
  ) async {
    await pump(tester);

    expect(
      find.bySemanticsLabel('Al menos un número: pendiente'),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextField).at(2), 'abc1');
    await tester.pump();

    expect(
      find.bySemanticsLabel('Al menos un número: cumplido'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Al menos 8 caracteres: pendiente'),
      findsOneWidget,
    );
  });

  testWidgets('el paso de términos bloquea el envío hasta aceptar', (
    tester,
  ) async {
    when(
      () => register(any(), completingProfile: any(named: 'completingProfile')),
    ).thenAnswer((_) async => const Success(null));
    await pump(tester);
    await completeUntilTerms(tester);

    expect(openAccountButton(tester).onPressed, isNull);
    expect(find.text(AuthTexts.termsRequired), findsOneWidget);

    await tapText(tester, 'Acepto los términos y condiciones');

    expect(openAccountButton(tester).onPressed, isNotNull);
    expect(find.text(AuthTexts.termsRequired), findsNothing);
    await tapText(tester, 'Abrir mi cuenta');
    await tester.pump();

    verify(() => register(any(), completingProfile: false)).called(1);
  });

  testWidgets('correo ya registrado: error junto al campo sin perder datos', (
    tester,
  ) async {
    when(
      () => register(any(), completingProfile: any(named: 'completingProfile')),
    ).thenAnswer((_) async => const Err(Failure.validation('email')));
    await pump(tester);
    await completeUntilTerms(tester);
    await tapText(tester, 'Acepto los términos y condiciones');

    await tapText(tester, 'Abrir mi cuenta');
    await tester.pump();

    expect(find.text('Paso 1 de 4'), findsOneWidget);
    expect(
      find.text(AuthTexts.fieldError('email', fromServer: true)),
      findsOneWidget,
    );
    expect(find.text('Ana Pérez'), findsOneWidget);
    expect(find.text('ana@bi.test'), findsOneWidget);
  });
}
