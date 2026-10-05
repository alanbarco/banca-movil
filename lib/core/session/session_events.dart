import 'dart:async';

import 'package:equatable/equatable.dart';

sealed class SessionEvent extends Equatable {
  const SessionEvent();
}

final class SignedIn extends SessionEvent {
  const SignedIn({required this.uid, required this.segment});

  final String uid;
  final String segment;

  @override
  List<Object?> get props => [uid, segment];
}

/// Se publica ANTES de cerrar la sesión para que cada feature limpie lo suyo
/// (p. ej. token de push) mientras aún hay credenciales.
final class SigningOut extends SessionEvent {
  const SigningOut({required this.uid});

  final String uid;

  @override
  List<Object?> get props => [uid];
}

final class SegmentChanged extends SessionEvent {
  const SegmentChanged({required this.oldSegment, required this.newSegment});

  final String oldSegment;
  final String newSegment;

  @override
  List<Object?> get props => [oldSegment, newSegment];
}

/// Bus de eventos de sesión publicado por `auth`.
class SessionEvents {
  /// Tope de espera de las limpiezas: sin red, el cierre de sesión no se
  /// bloquea.
  static const cleanupTimeout = Duration(seconds: 3);

  final _controller = StreamController<SessionEvent>.broadcast(sync: true);
  final _signOutCleanups = <Future<void> Function(String uid)>[];

  Stream<SessionEvent> get stream => _controller.stream;

  void publish(SessionEvent event) {
    if (!_controller.isClosed) _controller.add(event);
  }

  /// Registra una limpieza que necesita credenciales (p. ej. borrar el token
  /// de push en Firestore); `auth` la espera antes de cerrar la sesión.
  void addSignOutCleanup(Future<void> Function(String uid) cleanup) =>
      _signOutCleanups.add(cleanup);

  /// Publica [SigningOut] y espera las limpiezas (máximo [timeout]). Los
  /// errores de cada limpieza no impiden cerrar la sesión.
  Future<void> signingOut(
    String uid, {
    Duration timeout = cleanupTimeout,
  }) async {
    publish(SigningOut(uid: uid));
    await Future.wait([
      for (final cleanup in _signOutCleanups)
        Future(() => cleanup(uid)).catchError((Object _) {}),
    ]).timeout(timeout, onTimeout: () => const []);
  }

  Future<void> dispose() => _controller.close();
}
