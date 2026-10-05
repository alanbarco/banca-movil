import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/observability/app_logger.dart';
import '../../../../core/observability/observability_service.dart';
import '../../../../core/session/current_user_profile.dart';
import '../../../../core/session/session_events.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/entities/interest.dart';
import '../../domain/entities/registration_data.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/customer_provisioning_datasource.dart';
import '../datasources/firebase_auth_datasource.dart';
import '../datasources/onboarding_seed_datasource.dart';
import '../datasources/user_profile_datasource.dart';

/// Combina Firebase Auth y el perfil de Firestore en una única sesión, la
/// expone a otras features vía [CurrentUserProfile] y publica
/// [SessionEvents].
class AuthRepositoryImpl implements AuthRepository, CurrentUserProfile {
  AuthRepositoryImpl({
    required FirebaseAuthDatasource auth,
    required UserProfileDatasource profiles,
    required CustomerProvisioningDatasource provisioning,
    required OnboardingSeedDatasource seeds,
    required SessionEvents sessionEvents,
    required ObservabilityService observability,
    this.provisioningTimeout = const Duration(seconds: 20),
    AppLogger? logger,
  }) : _auth = auth,
       _profiles = profiles,
       _provisioning = provisioning,
       _seeds = seeds,
       _events = sessionEvents,
       _observability = observability,
       _logger = logger ?? AppLogger('auth') {
    _authSubscription = _auth.authStateChanges().listen(_onAuthUser);
  }

  final FirebaseAuthDatasource _auth;
  final UserProfileDatasource _profiles;
  final CustomerProvisioningDatasource _provisioning;
  final OnboardingSeedDatasource _seeds;
  final SessionEvents _events;
  final ObservabilityService _observability;
  final AppLogger _logger;

  /// Sin red el batch queda en cola; no se deja al cliente esperando.
  final Duration provisioningTimeout;

  final _sessions = StreamController<AuthSession>.broadcast();
  late final StreamSubscription<AuthUser?> _authSubscription;
  StreamSubscription<UserProfile?>? _profileSubscription;
  AuthSession? _current;

  // --- Sesión ---------------------------------------------------------------

  @override
  Stream<AuthSession> get session =>
      _replaying(_sessions.stream, () => _current);

  @override
  AuthSession? get currentSession => _current;

  @override
  bool get hasAuthAccount => _auth.currentUser != null;

  void _onAuthUser(AuthUser? user) {
    unawaited(_profileSubscription?.cancel());
    _profileSubscription = null;
    if (user == null) {
      _emit(const SignedOutSession());
      return;
    }
    _profileSubscription = _profiles
        .watch(user.uid)
        .listen(
          (profile) => _emit(
            profile == null
                ? ProfileMissingSession(uid: user.uid, email: user.email)
                : ActiveSession(profile),
          ),
          onError: (Object error, StackTrace stackTrace) {
            _logger.error('no se pudo leer el perfil', error: error);
            unawaited(
              _observability.recordError(
                error,
                stackTrace,
                reason: 'profile_watch',
              ),
            );
          },
        );
  }

  void _emit(AuthSession next) {
    final previous = _current;
    if (next == previous) return;
    _current = next;
    _publishSessionEvents(previous, next);
    _sessions.add(next);
  }

  void _publishSessionEvents(AuthSession? previous, AuthSession next) {
    if (next is! ActiveSession) return;
    final profile = next.profile;
    if (previous is ActiveSession && previous.profile.uid == profile.uid) {
      if (previous.profile.segment != profile.segment) {
        _events.publish(
          SegmentChanged(
            oldSegment: previous.profile.segment.wireName,
            newSegment: profile.segment.wireName,
          ),
        );
      }
      return;
    }
    _events.publish(
      SignedIn(uid: profile.uid, segment: profile.segment.wireName),
    );
  }

  // --- CurrentUserProfile ---------------------------------------------------

  @override
  SessionUser? get current => _toSessionUser(_current);

  @override
  Stream<SessionUser?> get user => session.map(_toSessionUser).distinct();

  static SessionUser? _toSessionUser(AuthSession? session) {
    if (session is! ActiveSession) return null;
    final profile = session.profile;
    return SessionUser(
      uid: profile.uid,
      segment: profile.segment.wireName,
      interests: [for (final i in profile.interests) i.wireName],
      notificationsEnabled: profile.notificationsEnabled,
    );
  }

  @override
  Stream<UserProfile?> watchProfile() =>
      session.map((s) => s is ActiveSession ? s.profile : null);

  // --- Operaciones -----------------------------------------------------------

  @override
  Future<Result<void>> signIn({
    required String email,
    required String password,
  }) => _guard('sign_in', () => _auth.signIn(email, password));

  @override
  Future<Result<void>> register(RegistrationData data) {
    return _guard('register', () async {
      // Un intento previo pudo crear la cuenta y fallar al aprovisionar.
      final existing = _auth.currentUser;
      final user = existing != null && existing.email == data.email
          ? existing
          : await _auth.createUser(data.email, data.password);
      await _provision(user, data);
    });
  }

  @override
  Future<Result<void>> completeProfile(RegistrationData data) {
    return _guard('complete_profile', () async {
      final user = _auth.currentUser;
      if (user == null) throw const _NoAuthenticatedUser();
      await _provision(user, data);
    });
  }

  Future<void> _provision(AuthUser user, RegistrationData data) {
    return _provisioning
        .provision(
          uid: user.uid,
          email: user.email,
          data: data,
          seed: _seeds.load(),
        )
        .timeout(provisioningTimeout);
  }

  @override
  Future<Result<void>> signOut() {
    return _guard('sign_out', () async {
      final user = _auth.currentUser;
      if (user != null) await _events.signingOut(user.uid);
      await _auth.signOut();
    });
  }

  @override
  Future<Result<void>> sendPasswordReset(String email) async {
    final result = await _guard(
      'password_reset',
      () => _auth.sendPasswordReset(email),
    );
    // Responder igual exista o no el correo (FR-006).
    final failure = result.failureOrNull;
    if (failure is UnauthorizedFailure || failure is NotFoundFailure) {
      return const Success(null);
    }
    return result;
  }

  @override
  Future<Result<void>> updateInterests(List<Interest> interests) {
    return _guard('update_interests', () async {
      final user = _auth.currentUser;
      if (user == null) throw const _NoAuthenticatedUser();
      await _profiles.updateInterests(user.uid, interests);
    });
  }

  @override
  Future<Result<void>> updateNotificationsEnabled({required bool enabled}) {
    return _guard('update_notifications', () async {
      final user = _auth.currentUser;
      if (user == null) throw const _NoAuthenticatedUser();
      await _profiles.updateNotificationsEnabled(user.uid, enabled: enabled);
    });
  }

  /// Ejecuta [action] y traduce cualquier excepción a [Failure].
  Future<Result<void>> _guard(
    String operation,
    Future<void> Function() action,
  ) async {
    try {
      await action();
      return const Success(null);
    } on Object catch (error, stackTrace) {
      final failure = mapError(error);
      _logger.warning('$operation falló', {'reason': failure.reason});
      if (failure is UnknownFailure || failure is ServerFailure) {
        unawaited(
          _observability.recordError(error, stackTrace, reason: operation),
        );
      }
      return Err(failure);
    }
  }

  /// Traducción de errores de Firebase a fallas de dominio.
  ///
  /// Credenciales inválidas, usuario inexistente o contraseña incorrecta se
  /// reportan igual para no revelar si el correo existe (FR-006).
  static Failure mapError(Object error) {
    if (error is FirebaseAuthException) {
      return switch (error.code) {
        'email-already-in-use' ||
        'invalid-email' => const Failure.validation('email'),
        'weak-password' => const Failure.validation('password'),
        'invalid-credential' ||
        'wrong-password' ||
        'user-not-found' ||
        'user-disabled' ||
        'INVALID_LOGIN_CREDENTIALS' => const Failure.unauthorized(),
        'network-request-failed' => const Failure.network(),
        'too-many-requests' => const Failure.server(),
        _ => Failure.unknown(error),
      };
    }
    if (error is FirebaseException) {
      return switch (error.code) {
        'unavailable' => const Failure.network(),
        'deadline-exceeded' => const Failure.timeout(),
        'permission-denied' ||
        'unauthenticated' => const Failure.unauthorized(),
        'not-found' => const Failure.notFound(),
        _ => Failure.unknown(error),
      };
    }
    if (error is TimeoutException) return const Failure.timeout();
    if (error is _NoAuthenticatedUser) return const Failure.unauthorized();
    return Failure.unknown(error);
  }

  Future<void> dispose() async {
    await _authSubscription.cancel();
    await _profileSubscription?.cancel();
    await _sessions.close();
  }
}

class _NoAuthenticatedUser implements Exception {
  const _NoAuthenticatedUser();
}

/// Stream que entrega primero el último valor conocido y luego los cambios.
Stream<T> _replaying<T extends Object>(
  Stream<T> changes,
  T? Function() current,
) {
  return Stream.multi((controller) {
    final value = current();
    if (value != null) controller.add(value);
    final subscription = changes.listen(
      controller.add,
      onError: controller.addError,
      onDone: controller.close,
    );
    controller.onCancel = subscription.cancel;
  });
}
