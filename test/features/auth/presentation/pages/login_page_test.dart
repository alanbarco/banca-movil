import 'package:bi_app/core/error/failure.dart';
import 'package:bi_app/features/auth/presentation/auth_texts.dart';
import 'package:bi_app/features/auth/presentation/bloc/login_cubit.dart';
import 'package:bi_app/features/auth/presentation/pages/login_page.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockLoginCubit extends MockCubit<LoginState> implements LoginCubit {}

void main() {
  late _MockLoginCubit cubit;

  setUp(() {
    cubit = _MockLoginCubit();
    when(
      () => cubit.submit(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async {});
  });

  Future<void> pump(WidgetTester tester, LoginState state) async {
    when(() => cubit.state).thenReturn(state);
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<LoginCubit>.value(
          value: cubit,
          child: const LoginPage(),
        ),
      ),
    );
  }

  FilledButton submitButton(WidgetTester tester) =>
      tester.widget<FilledButton>(find.byType(FilledButton));

  testWidgets('envía correo y contraseña ingresados', (tester) async {
    await pump(tester, const LoginState(email: 'ana@bi.test'));

    expect(find.text('ana@bi.test'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'secreta123');
    await tester.tap(find.text('Ingresar'));

    verify(
      () => cubit.submit(email: 'ana@bi.test', password: 'secreta123'),
    ).called(1);
  });

  testWidgets('mientras carga el botón se deshabilita', (tester) async {
    await pump(
      tester,
      const LoginState(email: 'ana@bi.test', status: LoginStatus.submitting),
    );

    expect(submitButton(tester).onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.bySemanticsLabel('Procesando'), findsOneWidget);
  });

  testWidgets('credenciales inválidas muestran un mensaje genérico', (
    tester,
  ) async {
    await pump(
      tester,
      const LoginState(
        status: LoginStatus.failure,
        failure: Failure.unauthorized(),
      ),
    );

    expect(find.text(AuthTexts.invalidCredentials), findsOneWidget);
    expect(find.text('Reintentar'), findsNothing);
    expect(submitButton(tester).onPressed, isNotNull);
  });

  testWidgets('error de red ofrece reintentar', (tester) async {
    await pump(
      tester,
      const LoginState(
        email: 'ana@bi.test',
        status: LoginStatus.failure,
        failure: Failure.network(),
      ),
    );
    await tester.enterText(find.byType(TextField).last, 'secreta123');

    expect(find.text(AuthTexts.network), findsOneWidget);
    await tester.tap(find.text('Reintentar'));

    verify(
      () => cubit.submit(email: 'ana@bi.test', password: 'secreta123'),
    ).called(1);
  });

  testWidgets('campo vacío se marca junto al campo', (tester) async {
    await pump(
      tester,
      const LoginState(
        status: LoginStatus.failure,
        failure: Failure.validation('password'),
      ),
    );

    expect(find.text('Ingresa tu contraseña.'), findsOneWidget);
    expect(find.text(AuthTexts.generic), findsNothing);
  });
}
