import 'dart:async';

import 'package:bi_app/core/error/failure.dart';
import 'package:bi_app/core/error/result.dart';
import 'package:bi_app/core/session/current_user_profile.dart';
import 'package:bi_app/core/session/session_events.dart';
import 'package:bi_app/features/auth/data/datasources/customer_provisioning_datasource.dart';
import 'package:bi_app/features/auth/data/datasources/firebase_auth_datasource.dart';
import 'package:bi_app/features/auth/data/datasources/onboarding_seed_datasource.dart';
import 'package:bi_app/features/auth/data/datasources/user_profile_datasource.dart';
import 'package:bi_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:bi_app/features/auth/domain/entities/auth_session.dart';
import 'package:bi_app/features/auth/domain/entities/interest.dart';
import 'package:bi_app/features/auth/domain/entities/segment.dart';
import 'package:bi_app/features/auth/domain/entities/user_profile.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fake_observability.dart';
import '../auth_fixtures.dart';

class _MockAuth extends Mock implements FirebaseAuthDatasource {}

class _MockProfiles extends Mock implements UserProfileDatasource {}

class _MockProvisioning extends Mock
    implements CustomerProvisioningDatasource {}

class _MockSeeds extends Mock implements OnboardingSeedDatasource {}

const _ana = AuthUser(uid: 'uid-ana', email: 'ana@bi.test');

void main() {
  late _MockAuth auth;
  late _MockProfiles profiles;
  late _MockProvisioning provisioning;
  late _MockSeeds seeds;
  late SessionEvents sessionEvents;
  late FakeObservabilityService observability;
  late StreamController<AuthUser?> authChanges;
  late StreamController<UserProfile?> profileChanges;
  late List<SessionEvent> published;
  late AuthRepositoryImpl repository;

  setUpAll(() {
    registerFallbackValue(validRegistration);
    registerFallbackValue(contractSeed);
  });

  setUp(() {
    auth = _MockAuth();
    profiles = _MockProfiles();
    provisioning = _MockProvisioning();
    seeds = _MockSeeds();
    sessionEvents = SessionEvents();
    observability = FakeObservabilityService();
    authChanges = StreamController<AuthUser?>.broadcast(sync: true);
    profileChanges = StreamController<UserProfile?>.broadcast(sync: true);
    published = [];
    sessionEvents.stream.listen(published.add);

    when(() => auth.authStateChanges()).thenAnswer((_) => authChanges.stream);
    when(() => auth.currentUser).thenReturn(null);
    when(() => profiles.watch(any())).thenAnswer((_) => profileChanges.stream);
    when(() => seeds.load()).thenReturn(contractSeed);
    when(
      () => provisioning.provision(
        uid: any(named: 'uid'),
        email: any(named: 'email'),
        data: any(named: 'data'),
        seed: any(named: 'seed'),
      ),
    ).thenAnswer((_) async {});

    repository = AuthRepositoryImpl(
      auth: auth,
      profiles: profiles,
      provisioning: provisioning,
      seeds: seeds,
      sessionEvents: sessionEvents,
      observability: observability,
    );
  });

  tearDown(() async {
    await repository.dispose();
    await authChanges.close();
    await profileChanges.close();
  });

  FirebaseAuthException authError(String code) =>
      FirebaseAuthException(code: code);

  group('mapeo de errores', () {
    Future<Failure?> signInFailing(Object error) async {
      when(() => auth.signIn(any(), any())).thenThrow(error);
      final result = await repository.signIn(email: 'a@b.co', password: 'x');
      return result.failureOrNull;
    }

    test(
      'credenciales inválidas → unauthorized (mismo mensaje genérico)',
      () async {
        for (final code in [
          'invalid-credential',
          'wrong-password',
          'user-not-found',
          'user-disabled',
        ]) {
          expect(
            await signInFailing(authError(code)),
            const Failure.unauthorized(),
            reason: code,
          );
        }
      },
    );

    test('red, demasiados intentos y desconocidos', () async {
      expect(
        await signInFailing(authError('network-request-failed')),
        const Failure.network(),
      );
      expect(
        await signInFailing(authError('too-many-requests')),
        const Failure.server(),
      );
      expect(await signInFailing(authError('otro')), isA<UnknownFailure>());
      expect(await signInFailing(StateError('x')), isA<UnknownFailure>());
      // Solo las fallas inesperadas van a Crashlytics.
      expect(observability.errors, hasLength(3));
    });

    test('errores de Firestore y timeout', () {
      expect(
        AuthRepositoryImpl.mapError(
          FirebaseException(plugin: 'firestore', code: 'unavailable'),
        ),
        const Failure.network(),
      );
      expect(
        AuthRepositoryImpl.mapError(
          FirebaseException(plugin: 'firestore', code: 'permission-denied'),
        ),
        const Failure.unauthorized(),
      );
      expect(
        AuthRepositoryImpl.mapError(TimeoutException('lento')),
        const Failure.timeout(),
      );
    });

    test(
      'correo ya registrado → validation(email); débil → password',
      () async {
        when(
          () => auth.createUser(any(), any()),
        ).thenThrow(authError('email-already-in-use'));
        expect(
          (await repository.register(validRegistration)).failureOrNull,
          const Failure.validation('email'),
        );

        when(
          () => auth.createUser(any(), any()),
        ).thenThrow(authError('weak-password'));
        expect(
          (await repository.register(validRegistration)).failureOrNull,
          const Failure.validation('password'),
        );
      },
    );
  });

  group('registro', () {
    test('crea la cuenta y aprovisiona con la semilla remota', () async {
      when(() => auth.createUser(any(), any())).thenAnswer((_) async => _ana);

      final result = await repository.register(validRegistration);

      expect(result, const Success<void>(null));
      verify(() => auth.createUser('ana@bi.test', 'secreta123')).called(1);
      verify(
        () => provisioning.provision(
          uid: 'uid-ana',
          email: 'ana@bi.test',
          data: validRegistration,
          seed: contractSeed,
        ),
      ).called(1);
    });

    test(
      'reintento tras fallo de aprovisionamiento no recrea la cuenta',
      () async {
        when(() => auth.currentUser).thenReturn(_ana);

        final result = await repository.register(validRegistration);

        expect(result.isSuccess, isTrue);
        verifyNever(() => auth.createUser(any(), any()));
        expect(repository.hasAuthAccount, isTrue);
      },
    );

    test('aprovisionamiento lento se reporta como timeout', () async {
      when(() => auth.createUser(any(), any())).thenAnswer((_) async => _ana);
      when(
        () => provisioning.provision(
          uid: any(named: 'uid'),
          email: any(named: 'email'),
          data: any(named: 'data'),
          seed: any(named: 'seed'),
        ),
      ).thenAnswer((_) => Completer<void>().future);
      final fast = AuthRepositoryImpl(
        auth: auth,
        profiles: profiles,
        provisioning: provisioning,
        seeds: seeds,
        sessionEvents: sessionEvents,
        observability: observability,
        provisioningTimeout: const Duration(milliseconds: 10),
      );

      final result = await fast.register(validRegistration);

      expect(result.failureOrNull, const Failure.timeout());
      await fast.dispose();
    });

    test('completeProfile exige usuario autenticado', () async {
      expect(
        (await repository.completeProfile(validRegistration)).failureOrNull,
        const Failure.unauthorized(),
      );

      when(() => auth.currentUser).thenReturn(_ana);
      expect(
        (await repository.completeProfile(validRegistration)).isSuccess,
        isTrue,
      );
    });
  });

  group('sesión', () {
    test('sin usuario → SignedOut', () async {
      authChanges.add(null);

      expect(repository.currentSession, const SignedOutSession());
      expect(await repository.session.first, const SignedOutSession());
    });

    test('usuario sin perfil → ProfileMissing; con perfil → Active', () async {
      final sessions = <AuthSession>[];
      repository.session.listen(sessions.add);

      authChanges.add(_ana);
      profileChanges
        ..add(null)
        ..add(anaProfile);
      await Future<void>.delayed(Duration.zero);

      expect(sessions, [
        const ProfileMissingSession(uid: 'uid-ana', email: 'ana@bi.test'),
        const ActiveSession(anaProfile),
      ]);
      expect(published, const [SignedIn(uid: 'uid-ana', segment: 'student')]);
    });

    test('cambio de segmento publica SegmentChanged', () {
      authChanges.add(_ana);
      profileChanges
        ..add(anaProfile)
        ..add(
          const UserProfile(
            uid: 'uid-ana',
            fullName: 'Ana Pérez',
            email: 'ana@bi.test',
            segment: Segment.entrepreneur,
            interests: [Interest.business],
          ),
        );

      expect(
        published.last,
        const SegmentChanged(oldSegment: 'student', newSegment: 'entrepreneur'),
      );
    });

    test('expone CurrentUserProfile sin PII', () async {
      final users = <SessionUser?>[];
      repository.user.listen(users.add);

      authChanges.add(_ana);
      profileChanges.add(anaProfile);
      await Future<void>.delayed(Duration.zero);

      const expected = SessionUser(
        uid: 'uid-ana',
        segment: 'student',
        interests: ['education'],
      );
      expect(repository.current, expected);
      expect(users.last, expected);
      expect(await repository.watchProfile().first, anaProfile);
    });

    test('signOut publica SigningOut antes de cerrar sesión', () async {
      when(() => auth.currentUser).thenReturn(_ana);
      when(() => auth.signOut()).thenAnswer((_) async {
        expect(published.last, const SigningOut(uid: 'uid-ana'));
      });

      expect((await repository.signOut()).isSuccess, isTrue);
      verify(() => auth.signOut()).called(1);
    });

    test('error al leer el perfil se reporta sin romper la sesión', () {
      authChanges.add(_ana);
      profileChanges.addError(StateError('permiso'));

      expect(observability.errors, hasLength(1));
      expect(repository.currentSession, isNull);
    });
  });

  group('recuperación y perfil', () {
    test('correo inexistente responde igual que uno existente', () async {
      when(
        () => auth.sendPasswordReset(any()),
      ).thenThrow(authError('user-not-found'));

      expect(
        await repository.sendPasswordReset('nadie@bi.test'),
        const Success<void>(null),
      );
    });

    test('error de red en recuperación sí se informa', () async {
      when(
        () => auth.sendPasswordReset(any()),
      ).thenThrow(authError('network-request-failed'));

      expect(
        (await repository.sendPasswordReset('a@b.co')).failureOrNull,
        const Failure.network(),
      );
    });

    test('actualiza intereses y notificaciones del usuario actual', () async {
      when(() => auth.currentUser).thenReturn(_ana);
      when(
        () => profiles.updateInterests(any(), any()),
      ).thenAnswer((_) async {});
      when(
        () => profiles.updateNotificationsEnabled(
          any(),
          enabled: any(named: 'enabled'),
        ),
      ).thenAnswer((_) async {});

      await repository.updateInterests([Interest.travel]);
      await repository.updateNotificationsEnabled(enabled: true);

      verify(
        () => profiles.updateInterests('uid-ana', [Interest.travel]),
      ).called(1);
      verify(
        () => profiles.updateNotificationsEnabled('uid-ana', enabled: true),
      ).called(1);
    });
  });
}
