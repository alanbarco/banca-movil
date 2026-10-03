import 'package:bi_app/core/error/failure.dart';
import 'package:bi_app/core/error/result.dart';
import 'package:bi_app/core/observability/analytics_events.dart';
import 'package:bi_app/features/auth/domain/usecases/send_password_reset.dart';
import 'package:bi_app/features/auth/domain/usecases/sign_in.dart';
import 'package:bi_app/features/auth/presentation/bloc/forgot_password_cubit.dart';
import 'package:bi_app/features/auth/presentation/bloc/login_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fake_observability.dart';

class _MockSignIn extends Mock implements SignIn {}

class _MockReset extends Mock implements SendPasswordReset {}

void main() {
  late _MockSignIn signIn;
  late FakeObservabilityService observability;

  setUp(() {
    signIn = _MockSignIn();
    observability = FakeObservabilityService();
  });

  void signInReturns(Result<void> result) {
    when(
      () => signIn(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async => result);
  }

  LoginCubit build({String initialEmail = ''}) => LoginCubit(
    signIn: signIn,
    observability: observability,
    initialEmail: initialEmail,
  );

  List<Object?> failureReasons() => observability
      .named(AnalyticsEvents.loginFailure)
      .map((e) => e.parameters[AnalyticsParams.reason])
      .toList();

  test('precarga el correo (tras cierre por inactividad)', () {
    expect(build(initialEmail: 'ana@bi.test').state.email, 'ana@bi.test');
  });

  blocTest<LoginCubit, LoginState>(
    'éxito: submitting → success y login_success',
    setUp: () => signInReturns(const Success(null)),
    build: build,
    act: (cubit) => cubit.submit(email: 'ana@bi.test', password: 'secreta123'),
    expect: () => const [
      LoginState(email: 'ana@bi.test', status: LoginStatus.submitting),
      LoginState(email: 'ana@bi.test', status: LoginStatus.success),
    ],
    verify: (_) =>
        expect(observability.named(AnalyticsEvents.loginSuccess), hasLength(1)),
  );

  blocTest<LoginCubit, LoginState>(
    'credenciales inválidas: conserva el correo y registra el motivo',
    setUp: () => signInReturns(const Err(Failure.unauthorized())),
    build: build,
    act: (cubit) => cubit.submit(email: 'ana@bi.test', password: 'mala'),
    skip: 1,
    expect: () => const [
      LoginState(
        email: 'ana@bi.test',
        status: LoginStatus.failure,
        failure: Failure.unauthorized(),
      ),
    ],
    verify: (_) => expect(failureReasons(), ['invalid_credentials']),
  );

  blocTest<LoginCubit, LoginState>(
    'error de red y otros errores',
    setUp: () => signInReturns(const Err(Failure.network())),
    build: build,
    act: (cubit) async {
      await cubit.submit(email: 'a@b.co', password: 'x');
      signInReturns(const Err(Failure.server()));
      await cubit.submit(email: 'a@b.co', password: 'x');
    },
    verify: (cubit) {
      expect(failureReasons(), ['network', 'other']);
      expect(cubit.state.failure, const Failure.server());
    },
  );

  blocTest<LoginCubit, LoginState>(
    'campos vacíos no cuentan como intento fallido',
    setUp: () => signInReturns(const Err(Failure.validation('email'))),
    build: build,
    act: (cubit) => cubit.submit(email: '', password: ''),
    verify: (cubit) {
      expect(cubit.state.status, LoginStatus.failure);
      expect(observability.named(AnalyticsEvents.loginFailure), isEmpty);
    },
  );

  group('ForgotPasswordCubit', () {
    late _MockReset reset;

    setUp(() => reset = _MockReset());

    blocTest<ForgotPasswordCubit, ForgotPasswordState>(
      'confirma el envío',
      setUp: () =>
          when(() => reset(any())).thenAnswer((_) async => const Success(null)),
      build: () => ForgotPasswordCubit(reset),
      act: (cubit) => cubit.submit('ana@bi.test'),
      expect: () => const [
        ForgotPasswordState(status: ForgotPasswordStatus.submitting),
        ForgotPasswordState(status: ForgotPasswordStatus.sent),
      ],
    );

    blocTest<ForgotPasswordCubit, ForgotPasswordState>(
      'informa errores (red o correo inválido)',
      setUp: () => when(
        () => reset(any()),
      ).thenAnswer((_) async => const Err(Failure.network())),
      build: () => ForgotPasswordCubit(reset),
      act: (cubit) => cubit.submit('ana@bi.test'),
      skip: 1,
      expect: () => const [
        ForgotPasswordState(
          status: ForgotPasswordStatus.failure,
          failure: Failure.network(),
        ),
      ],
    );
  });
}
