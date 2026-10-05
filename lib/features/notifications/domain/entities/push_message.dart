import 'package:equatable/equatable.dart';

enum PushType {
  movement,
  offer,
  announcement;

  /// Tipos desconocidos se tratan como comunicado.
  static PushType fromWire(Object? value) {
    for (final type in values) {
      if (type.name == value) return type;
    }
    return announcement;
  }
}

/// Notificación recibida (`contracts/push-notifications.md`).
class PushMessage extends Equatable {
  const PushMessage({
    required this.title,
    required this.body,
    this.type = PushType.announcement,
    this.route,
  });

  final String title;
  final String body;
  final PushType type;

  /// Pantalla a abrir al tocarla; se valida antes de navegar.
  final String? route;

  @override
  List<Object?> get props => [title, body, type, route];
}
