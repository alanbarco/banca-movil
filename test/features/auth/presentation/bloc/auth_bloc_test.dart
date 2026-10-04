import 'dart:async';

import 'package:bi_app/core/error/result.dart';
import 'package:bi_app/core/observability/analytics_events.dart';
import 'package:bi_app/core/session/session_status.dart';
import 'package:bi_app/core/session/session_timeout_service.dart';
import 'package:bi_app/core/storage/local_storage.dart';
import 'package:bi_app/core/storage/storage_keys.dart';
import 'package:bi_app/features/auth/domain/entities/auth_session.dart';
import 'package:bi_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:bi_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/fake_observability.dart';
import '../../auth_fixtures.dart';

class _MockRepository extends Mock implements AuthRepository {}

class _MockTimeout extends Mock implements SessionTimeoutService {}

void main() {
  late _MockRepository repository;
  late _MockTimeout timeout;
  late StreamController<AuthSession> sessions;
  late StreamController<void> timeouts;
  late LocalStorage storage;
  late FakeObservabilityService observability;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = await LocalStorage.create();
    repository = _MockRepository();
    timeout = _MockTimeout();
    observability = FakeObservabilityService();
    sessions = StreamController<AuthSession>();
    timeouts = StreamController<void>();
    when(() => repository.session).thenAnswer((_) => sessions.stream);
    when(() => timeout.timeouts).thenAnswer((_) => timeouts.stream);
    when(() => repository.signOut()).thenAnswer((_) async {
      sessions.add(const SignedOutSession());
      return const Success(null);
    });
  });

  tearDown(() async {
    await sessions.close();
    await timeouts.close();
  });

  AuthBloc build() => AuthBloc(
    repository: repository,
    sessionTimeout: timeout,
    storage: storage,
    observability: observability,
  );

  test('arranca en unknown (la app queda en /splash)', () {
    final bloc = build();

    expect(bloc.state, const AuthState.unknown());
    expect(bloc.status, SessionStatus.unknown);
    unawaited(bloc.close());
  });

  blocTest<AuthBloc, AuthState>(
    'sesión activa → authenticated, inicia inactividad y registra segmento',
    build: build,
    act: (_) => sessions.add(const ActiveSession(anaProfile)),
    expect: () => const [AuthState.authenticated(anaProfile)],
    verify: (bloc) {
      verify(() => timeout.start()).called(1);
      expect(observability.userId, 'uid-ana');
      expect(observability.userProperties, {'segment': 'student'});
      expect(bloc.status, SessionStatus.authenticated);
    },
  );

  blocTest<AuthBloc, AuthState>(
    'sin perfil → needsOnboarding con el correo pendiente',
    build: build,
    act: (_) => sessions.add(
      const ProfileMissingSession(uid: 'uid-ana', email: 'ana@bi.test'),
    ),
    expect: () => const [AuthState.needsOnboarding('ana@bi.test')],
    verify: (_) => verify(() => timeout.stop()).called(1),
  );

  blocTest<AuthBloc, AuthState>(
    'sin sesión → unauthenticated con el último correo guardado',
    setUp: () async {
      SharedPreferences.setMockInitialValues({
        StorageKeys.lastSignedInEmail: 'ana@bi.test',
      });
      storage = await LocalStorage.create();
    },
    build: build,
    act: (_) => sessions.add(const SignedOutSession()),
    expect: () => const [
      AuthState.unauthenticated(prefillEmail: 'ana@bi.test'),
    ],
  );

  blocTest<AuthBloc, AuthState>(
    'logout: marca borrado de caché, guarda el correo y cierra sesión',
    build: build,
    seed: () => const AuthState.authenticated(anaProfile),
    act: (bloc) => bloc.add(const LogoutRequested()),
    expect: () => const [
      AuthState.unauthenticated(prefillEmail: 'ana@bi.test'),
    ],
    verify: (_) {
      verify(() => repository.signOut()).called(1);
      verify(() => timeout.stop()).called(greaterThanOrEqualTo(1));
      expect(storage.getBool(StorageKeys.pendingCacheClear), isTrue);
      expect(storage.getString(StorageKeys.lastSignedInEmail), 'ana@bi.test');
      expect(observability.userId, isNull);
    },
  );

  blocTest<AuthBloc, AuthState>(
    'inactividad: emite session_timeout y vuelve a unauthenticated',
    build: build,
    seed: () => const AuthState.authenticated(anaProfile),
    act: (_) => timeouts.add(null),
    expect: () => const [
      AuthState.unauthenticated(prefillEmail: 'ana@bi.test'),
    ],
    verify: (_) {
      expect(observability.named(AnalyticsEvents.sessionTimeout), hasLength(1));
      verify(() => repository.signOut()).called(1);
    },
  );

  blocTest<AuthBloc, AuthState>(
    'inactividad sin sesión activa se ignora',
    build: build,
    act: (_) => timeouts.add(null),
    expect: () => const <AuthState>[],
    verify: (_) => verifyNever(() => repository.signOut()),
  );

  test('changes emite solo cambios de estado de sesión', () async {
    final bloc = build();
    final statuses = <SessionStatus>[];
    bloc.changes.listen(statuses.add);

    sessions
      ..add(const ActiveSession(anaProfile))
      ..add(const ActiveSession(anaProfile));
    await Future<void>.delayed(Duration.zero);
    sessions.add(const SignedOutSession());
    await Future<void>.delayed(Duration.zero);

    expect(statuses, [
      SessionStatus.authenticated,
      SessionStatus.unauthenticated,
    ]);
    await bloc.close();
  });
}
