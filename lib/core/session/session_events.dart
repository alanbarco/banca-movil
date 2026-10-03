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
  final _controller = StreamController<SessionEvent>.broadcast(sync: true);

  Stream<SessionEvent> get stream => _controller.stream;

  void publish(SessionEvent event) {
    if (!_controller.isClosed) _controller.add(event);
  }

  Future<void> dispose() => _controller.close();
}
