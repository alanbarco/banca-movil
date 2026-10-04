import 'dart:async';

import 'package:bi_app/core/flags/feature_flag_service.dart';
import 'package:bi_app/core/sdui/home_section_parser.dart';
import 'package:bi_app/features/personalization/domain/entities/home_layout.dart';

/// Flags en memoria: todo activo salvo lo que se apague.
class FakeFlags implements FeatureFlagService {
  final disabled = <String>{};

  /// Flags apagados solo para un segmento: `flag|segment`.
  final disabledFor = <String>{};
  final _changes = StreamController<void>.broadcast();

  @override
  bool isEnabled(String key, {String? segment}) =>
      !disabled.contains(key) && !disabledFor.contains('$key|$segment');

  @override
  Stream<void> get changes => _changes.stream;

  void turnOff(String key, {String? segment}) {
    segment == null ? disabled.add(key) : disabledFor.add('$key|$segment');
    _changes.add(null);
  }
}

Map<String, dynamic> section(
  String id,
  String type,
  int order, {
  List<String>? interests,
  String? flag,
  Map<String, dynamic> payload = const {},
}) => {
  'id': id,
  'type': type,
  'order': order,
  'interests': ?interests,
  'flag': ?flag,
  'payload': payload,
};

Map<String, dynamic> banner(String id, int order, {String? flag}) => section(
  id,
  'banner',
  order,
  flag: flag,
  payload: {'title': 'Banner $id', 'subtitle': 'Sub $id'},
);

Map<String, dynamic> tip(String id, int order, {List<String>? interests}) =>
    section(
      id,
      'tip',
      order,
      interests: interests,
      payload: {'title': 'Consejo $id', 'body': 'Cuerpo $id'},
    );

Map<String, dynamic> offerItem(String id, {List<String>? interests}) => {
  'id': id,
  'title': 'Oferta $id',
  'description': 'Descripción $id',
  'interests': ?interests,
  'route': '/offers/$id',
};

Map<String, dynamic> offers(
  String id,
  int order,
  List<Map<String, dynamic>> items, {
  List<String>? interests,
  String? flag,
}) => section(
  id,
  'offer_carousel',
  order,
  interests: interests,
  flag: flag,
  payload: {'items': items},
);

Map<String, dynamic> quickActions(String id, int order) => section(
  id,
  'quick_actions',
  order,
  payload: {
    'items': [
      {
        'id': 'fx',
        'label': 'Divisas',
        'icon': 'currency_exchange',
        'route': '/fx',
        'flag': 'fx_service',
      },
      {
        'id': 'profile',
        'label': 'Mi perfil',
        'icon': 'person',
        'route': '/profile',
      },
    ],
  },
);

/// `home_layout` con las secciones dadas por segmento.
Map<String, dynamic> layoutJson(
  Map<String, List<Map<String, dynamic>>> bySegment,
) => {
  'schemaVersion': 1,
  'segments': {
    for (final entry in bySegment.entries) entry.key: {'sections': entry.value},
  },
};

HomeLayout layoutOf(Map<String, List<Map<String, dynamic>>> bySegment) {
  const parser = HomeSectionParser();
  return HomeLayout(
    segments: {
      for (final entry in bySegment.entries)
        entry.key: parser.parseSections(entry.value),
    },
  );
}
