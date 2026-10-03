import 'dart:convert';
import 'dart:io';

import 'package:bi_app/core/sdui/home_section.dart';
import 'package:bi_app/core/sdui/home_section_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = HomeSectionParser();

  Map<String, dynamic> section(
    String id,
    String type, {
    int order = 1,
    Map<String, dynamic>? payload,
    Object? interests,
    Object? flag,
  }) => {
    'id': id,
    'type': type,
    'order': order,
    'payload': ?payload,
    'interests': ?interests,
    'flag': ?flag,
  };

  group('parseSections', () {
    test('parsea los tipos válidos y ordena por order', () {
      final result = parser.parseSections([
        section('tip', 'tip', order: 3, payload: {'title': 'T', 'body': 'B'}),
        section('acc', 'accounts_summary', order: 0, payload: {}),
        section(
          'banner',
          'banner',
          order: 1,
          payload: {'title': 'Hola', 'subtitle': 'Sub', 'route': '/fx'},
        ),
        section(
          'qa',
          'quick_actions',
          order: 2,
          flag: 'fx_service',
          payload: {
            'items': [
              {'id': 'fx', 'label': 'Divisas', 'icon': 'x', 'route': '/fx'},
            ],
          },
        ),
        section(
          'offers',
          'offer_carousel',
          order: 4,
          interests: ['travel'],
          payload: {
            'items': [
              {'id': 'o1', 'title': 'T', 'description': 'D'},
            ],
          },
        ),
      ]);

      expect(result.skipped, isEmpty);
      expect(result.sections.map((s) => s.type), [
        HomeSectionType.accountsSummary,
        HomeSectionType.banner,
        HomeSectionType.quickActions,
        HomeSectionType.tip,
        HomeSectionType.offerCarousel,
      ]);
      expect(result.sections[2].flag, 'fx_service');
      expect(result.sections.last.interests, ['travel']);
    });

    test('omite type desconocido y lo reporta', () {
      final result = parser.parseSections([
        section('acc', 'accounts_summary', order: 0),
        section('x', 'video_player', payload: {'url': 'a'}),
      ]);

      expect(result.sections.map((s) => s.id), ['acc']);
      expect(result.skipped, const [
        SkippedSection(
          id: 'x',
          type: 'video_player',
          reason: SkippedSection.unknownType,
        ),
      ]);
    });

    test('omite payloads inválidos sin afectar al resto', () {
      final result = parser.parseSections([
        section('b1', 'banner', payload: {'title': 'Sin subtítulo'}),
        section('t1', 'tip', payload: {'title': 'T', 'body': 42}),
        section('o1', 'offer_carousel', payload: {'items': <Object>[]}),
        section(
          'q1',
          'quick_actions',
          payload: {
            'items': [
              {'id': 'fx', 'label': 'Divisas'},
            ],
          },
        ),
        section('t2', 'tip', payload: {'title': 'T', 'body': 'B'}),
        section(
          't3',
          'tip',
          payload: {'title': 'T', 'body': 'B'},
          interests: 'travel',
        ),
      ]);

      expect(result.sections.map((s) => s.id), ['t2']);
      expect(result.skipped.map((s) => s.id), ['b1', 't1', 'o1', 'q1', 't3']);
      expect(result.skipped.map((s) => s.reason).toSet(), {
        SkippedSection.invalidPayload,
      });
    });

    test('omite secciones sin id/order, no-objeto o con id repetido', () {
      final result = parser.parseSections([
        'texto',
        {'type': 'tip', 'order': 1},
        {
          'id': 'a',
          'type': 'tip',
          'payload': {'title': 'T', 'body': 'B'},
        },
        section('t', 'tip', payload: {'title': 'T', 'body': 'B'}),
        section('t', 'tip', payload: {'title': 'T2', 'body': 'B2'}),
      ]);

      expect(result.sections, hasLength(1));
      expect(result.sections.single.payload['title'], 'T');
      expect(result.skipped.map((s) => s.reason), [
        SkippedSection.invalidSection,
        SkippedSection.invalidSection,
        SkippedSection.invalidSection,
        SkippedSection.duplicateId,
      ]);
    });
  });

  group('parseLayout', () {
    Map<String, dynamic> layout({int schemaVersion = 1}) => {
      'schemaVersion': schemaVersion,
      'segments': {
        'default': {
          'sections': [section('acc', 'accounts_summary', order: 0)],
        },
        'student': {
          'sections': [
            section('acc', 'accounts_summary', order: 0),
            section('tip', 'tip', payload: {'title': 'T', 'body': 'B'}),
          ],
        },
      },
    };

    test('usa el layout del segmento', () {
      final result = parser.parseLayout(layout(), segment: 'student');

      expect(result!.sections.map((s) => s.id), ['acc', 'tip']);
    });

    test('cae a default si el segmento no existe o es null', () {
      expect(
        parser.parseLayout(layout(), segment: 'entrepreneur')!.sections,
        hasLength(1),
      );
      expect(parser.parseLayout(layout())!.sections, hasLength(1));
    });

    test('rechaza schemaVersion mayor a la soportada', () {
      expect(parser.parseLayout(layout(schemaVersion: 2)), isNull);
    });

    test('rechaza estructura inválida o sin schemaVersion', () {
      expect(parser.parseLayout({'segments': <String, dynamic>{}}), isNull);
      expect(parser.parseLayout({'schemaVersion': 1, 'segments': []}), isNull);
      expect(
        parser.parseLayout({
          'schemaVersion': 1,
          'segments': {'student': <String, dynamic>{}},
        }),
        isNull,
      );
    });

    test(
      'los defaults locales son válidos y cada segmento abre con cuentas',
      () {
        final raw = File(
          'assets/config/remote_config_defaults.json',
        ).readAsStringSync();
        final json = jsonDecode(raw) as Map<String, dynamic>;
        final homeLayout = json['home_layout'] as Map<String, dynamic>;

        for (final segment in [
          'default',
          'student',
          'professional',
          'entrepreneur',
        ]) {
          final result = parser.parseLayout(homeLayout, segment: segment)!;
          expect(result.skipped, isEmpty, reason: segment);
          expect(
            result.sections.first.type,
            HomeSectionType.accountsSummary,
            reason: segment,
          );
          expect(result.sections.first.order, 0, reason: segment);
        }
      },
    );
  });
}
