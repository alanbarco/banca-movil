import 'package:bi_app/core/error/failure.dart';
import 'package:bi_app/core/error/result.dart';
import 'package:bi_app/features/auth/domain/entities/interest.dart';
import 'package:bi_app/features/auth/domain/entities/registration_data.dart';
import 'package:bi_app/features/auth/domain/entities/segment.dart';
import 'package:bi_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:bi_app/features/auth/domain/usecases/register_customer.dart';
import 'package:bi_app/features/auth/domain/usecases/send_password_reset.dart';
import 'package:bi_app/features/auth/domain/usecases/sign_in.dart';
import 'package:bi_app/features/auth/domain/usecases/sign_out.dart';
import 'package:bi_app/features/auth/domain/usecases/watch_auth_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../auth_fixtures.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

RegistrationData _with({
  String? fullName,
  String? email,
  String? password,
  List<Interest>? interests,
  bool? termsAccepted,
  String? termsVersion,
}) {
  const base = validRegistration;
  return RegistrationData(
    fullName: fullName ?? base.fullName,
    email: email ?? base.email,
    password: password ?? base.password,
    segment: Segment.professional,
    interests: interests ?? base.interests,
    termsAccepted: termsAccepted ?? base.termsAccepted,
    termsVersion: termsVersion ?? base.termsVersion,
  );
}

void main() {
  late _MockAuthRepository repository;
  late RegisterCustomer registerCustomer;

  setUpAll(() => registerFallbackValue(validRegistration));

  setUp(() {
    repository = _MockAuthRepository();
    registerCustomer = RegisterCustomer(repository);
    when(
      () => repository.register(any()),
    ).thenAnswer((_) async => const Success(null));
    when(
      () => repository.completeProfile(any()),
    ).thenAnswer((_) async => const Success(null));
  });

  group('RegisterCustomer', () {
    test('datos válidos se envían al repositorio', () async {
      final result = await registerCustomer(validRegistration);

      expect(result, const Success<void>(null));
      verify(() => repository.register(validRegistration)).called(1);
    });

    final invalidCases = <String, (RegistrationData, String)>{
      'nombre corto': (_with(fullName: ' Al '), 'fullName'),
      'nombre largo': (_with(fullName: 'A' * 81), 'fullName'),
      'correo inválido': (_with(email: 'ana@'), 'email'),
      'contraseña corta': (_with(password: 'abc123'), 'password'),
      'contraseña sin números': (_with(password: 'solamente'), 'password'),
      'contraseña sin letras': (_with(password: '12345678'), 'password'),
      'sin intereses': (_with(interests: []), 'interests'),
      'más de 5 intereses': (
        _with(interests: [...Interest.values, Interest.travel]),
        'interests',
      ),
      'intereses repetidos': (
        _with(interests: [Interest.travel, Interest.travel]),
        'interests',
      ),
      'términos no aceptados': (_with(termsAccepted: false), 'terms'),
      'sin versión de términos': (_with(termsVersion: ''), 'terms'),
    };

    for (final MapEntry(key: name, value: (data, field))
        in invalidCases.entries) {
      test('rechaza $name sin ir a la red', () async {
        final result = await registerCustomer(data);

        expect(result, Err<void>(Failure.validation(field)));
        verifyNever(() => repository.register(any()));
      });
    }

    test(
      'propaga validation(email) del servidor (correo ya registrado)',
      () async {
        when(
          () => repository.register(any()),
        ).thenAnswer((_) async => const Err(Failure.validation('email')));

        final result = await registerCustomer(validRegistration);

        expect(result, const Err<void>(Failure.validation('email')));
      },
    );

    test(
      'al completar perfil no exige contraseña y usa completeProfile',
      () async {
        final data = _with(password: '');

        final result = await registerCustomer(data, completingProfile: true);

        expect(result.isSuccess, isTrue);
        verify(() => repository.completeProfile(data)).called(1);
        verifyNever(() => repository.register(any()));
      },
    );

    test('hasAuthAccount delega en el repositorio', () {
      when(() => repository.hasAuthAccount).thenReturn(true);

      expect(registerCustomer.hasAuthAccount, isTrue);
    });
  });

  group('PasswordPolicy', () {
    test('acepta letras con acentos y números', () {
      expect(PasswordPolicy.isValid('contraseña1'), isTrue);
      expect(PasswordPolicy.hasMinLength('1234567'), isFalse);
    });
  });

  group('otros casos de uso', () {
    test('SignIn valida campos vacíos y recorta el correo', () async {
      when(
        () => repository.signIn(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => const Success(null));
      final signIn = SignIn(repository);

      expect(
        await signIn(email: ' ', password: 'x'),
        const Err<void>(Failure.validation('email')),
      );
      expect(
        await signIn(email: 'a@b.co', password: ''),
        const Err<void>(Failure.validation('password')),
      );
      await signIn(email: ' a@b.co ', password: 'x');
      verify(() => repository.signIn(email: 'a@b.co', password: 'x')).called(1);
    });

    test('SendPasswordReset valida el formato del correo', () async {
      when(
        () => repository.sendPasswordReset(any()),
      ).thenAnswer((_) async => const Success(null));
      final reset = SendPasswordReset(repository);

      expect(
        await reset('no-es-correo'),
        const Err<void>(Failure.validation('email')),
      );
      expect((await reset(' ana@bi.test ')).isSuccess, isTrue);
      verify(() => repository.sendPasswordReset('ana@bi.test')).called(1);
    });

    test('SignOut y WatchAuthState delegan en el repositorio', () async {
      when(
        () => repository.signOut(),
      ).thenAnswer((_) async => const Success(null));
      when(() => repository.session).thenAnswer((_) => const Stream.empty());

      expect((await SignOut(repository)()).isSuccess, isTrue);
      expect(await WatchAuthState(repository)().isEmpty, isTrue);
    });
  });
}
