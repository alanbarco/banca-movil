import 'package:equatable/equatable.dart';

/// Oferta publicada en un `offer_carousel` del inicio.
class Offer extends Equatable {
  const Offer({
    required this.id,
    required this.title,
    required this.description,
    this.interests = const [],
  });

  /// `null` si el item no cumple el contrato de `offer_carousel`.
  static Offer? fromPayload(Object? item) {
    if (item is! Map<String, dynamic>) return null;
    final id = item['id'];
    final title = item['title'];
    final description = item['description'];
    final interests = item['interests'];
    if (id is! String || title is! String || description is! String) {
      return null;
    }
    return Offer(
      id: id,
      title: title,
      description: description,
      interests: interests is List
          ? interests.whereType<String>().toList()
          : const [],
    );
  }

  final String id;
  final String title;
  final String description;
  final List<String> interests;

  @override
  List<Object?> get props => [id, title, description, interests];
}
