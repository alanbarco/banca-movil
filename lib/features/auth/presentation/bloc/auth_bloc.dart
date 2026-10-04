import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/observability/analytics_events.dart';
import '../../../../core/observability/observability_service.dart';
import '../../../../core/session/session_status.dart';
import '../../../../core/session/session_timeout_service.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../core/storage/storage_keys.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/auth_repository.dart';

sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => const [];
}

final class LogoutRequested extends AuthEvent {
  const LogoutRequested();
}

final class _SessionChanged extends AuthEvent {
  const _SessionChanged(this.session);

  final AuthSession session;

  @override
  List<Object?> get props => [session];
}

final class _SessionTimedOut extends AuthEvent {
  const _SessionTimedOut();
}

class AuthState extends Equatable {
  const AuthState._({
    required this.status,
    this.profile,
    this.pendingEmail,
    this.prefillEmail,
  });

  const AuthState.unknown() : this._(status: SessionStatus.unknown);

  const AuthState.unauthenticated({String? prefillEmail})
    : this._(status: SessionStatus.unauthenticated, prefillEmail: prefillEmail);

  const AuthState.needsOnboarding(String email)
    : this._(status: SessionStatus.needsOnboarding, pendingEmail: email);

  const AuthState.authenticated(UserProfile profile)
    : this._(status: SessionStatus.authenticated, profile: profile);

  final SessionStatus status;
  final UserProfile? profile;

  /// Correo de la cuenta creada cuyo perfil falta completar.
  final String? pendingEmail;

  /// Correo para precargar el login tras un cierre de sesión.
  final String? prefillEmail;

  @override
  List<Object?> get props => [status, profile, pendingEmail, prefillEmail];
}

/// Fuente única del estado de sesión para el router y las pantallas.
///
/// Controla además la inactividad (FR-007) y la limpieza al cerrar sesión
/// (FR-008).
class AuthBloc extends Bloc<AuthEvent, AuthState>
    implements SessionStatusSource {
  AuthBloc({
    required AuthRepository repository,
    required SessionTimeoutService sessionTimeout,
    required LocalStorage storage,
    required ObservabilityService observability,
  }) : _repository = repository,
       _timeout = sessionTimeout,
       _storage = storage,
       _observability = observability,
       super(const AuthState.unknown()) {
    on<_SessionChanged>(_onSessionChanged);
    on<LogoutRequested>((_, emit) => _logout(emit));
    on<_SessionTimedOut>(_onTimedOut);

    _subscriptions
      ..add(repository.session.listen((s) => add(_SessionChanged(s))))
      ..add(_timeout.timeouts.listen((_) => add(const _SessionTimedOut())));
  }

  final AuthRepository _repository;
  final SessionTimeoutService _timeout;
  final LocalStorage _storage;
  final ObservabilityService _observability;
  final List<StreamSubscription<Object?>> _subscriptions = [];

  @override
  SessionStatus get status => state.status;

  @override
  Stream<SessionStatus> get changes =>
      stream.map((state) => state.status).distinct();

  Future<void> _onSessionChanged(
    _SessionChanged event,
    Emitter<AuthState> emit,
  ) async {
    switch (event.session) {
      case SignedOutSession():
        _timeout.stop();
        emit(
          AuthState.unauthenticated(
            prefillEmail:
                state.prefillEmail ??
                _storage.getString(StorageKeys.lastSignedInEmail),
          ),
        );
      case ProfileMissingSession(:final email):
        _timeout.stop();
        emit(AuthState.needsOnboarding(email));
      case ActiveSession(:final profile):
        final previous = state.profile;
        if (state.status != SessionStatus.authenticated) _timeout.start();
        if (previous?.uid != profile.uid ||
            previous?.segment != profile.segment) {
          await _observability.setUserId(profile.uid);
          await _observability.setUserProperty(
            AnalyticsUserProperties.segment,
            profile.segment.wireName,
          );
        }
        emit(AuthState.authenticated(profile));
    }
  }

  Future<void> _onTimedOut(
    _SessionTimedOut event,
    Emitter<AuthState> emit,
  ) async {
    if (state.status != SessionStatus.authenticated) return;
    await _observability.logEvent(AnalyticsEvents.sessionTimeout);
    await _logout(emit);
  }

  Future<void> _logout(Emitter<AuthState> emit) async {
    _timeout.stop();
    final email = state.profile?.email ?? state.pendingEmail;
    // La caché de Firestore se borra en el próximo arranque, antes de leer.
    await _storage.setBool(StorageKeys.pendingCacheClear, value: true);
    if (email != null) {
      await _storage.setString(StorageKeys.lastSignedInEmail, email);
    }
    await _repository.signOut();
    await _observability.setUserId(null);
    emit(AuthState.unauthenticated(prefillEmail: email));
  }

  @override
  Future<void> close() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    return super.close();
  }
}
