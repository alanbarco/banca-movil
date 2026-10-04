import 'package:bi_app/core/sdui/home_section.dart';
import 'package:bi_app/core/sdui/home_section_parser.dart';
import 'package:bi_app/features/personalization/domain/entities/home_layout.dart';
import 'package:bi_app/features/personalization/domain/usecases/resolve_home_layout.dart';
import 'package:flutter_test/flutter_test.dart';

import '../personalization_fixtures.dart';

void main() {
  late FakeFlags flags;
  late ResolveHomeLayout resolve;

  final fallback = layoutOf({
    'default': [banner('local', 0)],
  });

  setUp(() {
    flags = FakeFlags();
    resolve = ResolveHomeLayout(flags);
  });

  List<String> ids(ResolvedHome home) =>
      home.sections.map((s) => s.id).toList();

  group('origen del layout', () {
    final layout = layoutOf({
      'default': [banner('general', 0)],
      'student': [banner('estudiante', 0)],
    });

    test('usa el layout del segmento del cliente', () {
      final home = resolve(
        layout: layout,
        fallback: fallback,
        segment: 'student',
      );

      expect(ids(home), ['estudiante']);
      expect(home.usedFallback, isFalse);
    });

    test('segmento sin layout propio → default', () {
      final home = resolve(
        layout: layout,
        fallback: fallback,
        segment: 'entrepreneur',
      );

      expect(ids(home), ['general']);
    });

    test('layout remoto vacío o inválido → defaults locales', () {
      final home = resolve(
        layout: const HomeLayout(),
        fallback: fallback,
        segment: 'student',
      );

      expect(ids(home), ['local']);
      expect(home.usedFallback, isTrue);
    });
  });

  test('ordena por order del banco', () {
    final layout = layoutOf({
      'default': [banner('c', 3), banner('a', 1), banner('b', 2)],
    });

    final home = resolve(layout: layout, fallback: fallback, segment: null);

    expect(ids(home), ['a', 'b', 'c']);
  });

  group('flags', () {
    test('sección con flag apagado no se muestra', () {
      flags.turnOff('offers');
      final layout = layoutOf({
        'default': [
          banner('visible', 0),
          offers('ofertas', 1, [offerItem('o1')], flag: 'offers'),
        ],
      });

      final home = resolve(layout: layout, fallback: fallback, segment: null);

      expect(ids(home), ['visible']);
    });

    test('flag apagado solo para un segmento', () {
      flags.turnOff('offers', segment: 'student');
      final layout = layoutOf({
        'default': [
          offers('ofertas', 0, [offerItem('o1')], flag: 'offers'),
        ],
      });

      expect(
        ids(resolve(layout: layout, fallback: fallback, segment: 'student')),
        isEmpty,
      );
      expect(
        ids(
          resolve(layout: layout, fallback: fallback, segment: 'professional'),
        ),
        ['ofertas'],
      );
    });

    test('acciones rápidas con flag apagado se ocultan', () {
      flags.turnOff('fx_service');
      final layout = layoutOf({
        'default': [quickActions('acciones', 0)],
      });

      final home = resolve(layout: layout, fallback: fallback, segment: null);

      final items = home.sections.single.payload['items'] as List;
      expect(items.map((i) => (i as Map)['id']), ['profile']);
    });
  });

  group('intereses', () {
    final layout = layoutOf({
      'default': [
        tip('ahorro', 1, interests: ['savings']),
        tip('viajes', 1, interests: ['travel']),
        banner('general', 1),
        offers('ofertas', 2, [
          offerItem('general'),
          offerItem('inversion', interests: ['investment']),
          offerItem('viaje', interests: ['travel']),
        ]),
      ],
    });

    test('consejos con intereses se filtran', () {
      final home = resolve(
        layout: layout,
        fallback: fallback,
        segment: null,
        interests: ['travel'],
      );

      expect(ids(home), containsAllInOrder(['viajes', 'general', 'ofertas']));
      expect(ids(home), isNot(contains('ahorro')));
    });

    test('a igual order, lo relevante va primero', () {
      final home = resolve(
        layout: layout,
        fallback: fallback,
        segment: null,
        interests: ['travel'],
      );

      expect(ids(home).first, 'viajes');
    });

    test('ofertas: se filtran y las que coinciden van primero', () {
      final home = resolve(
        layout: layout,
        fallback: fallback,
        segment: null,
        interests: ['travel'],
      );

      final carousel = home.sections.firstWhere((s) => s.id == 'ofertas');
      final items = carousel.payload['items'] as List;
      expect(items.map((i) => (i as Map)['id']), ['viaje', 'general']);
    });

    test('carrusel sin ofertas para el cliente no se muestra', () {
      final onlyInvestment = layoutOf({
        'default': [
          offers('ofertas', 0, [
            offerItem('inversion', interests: ['investment']),
          ]),
        ],
      });

      final home = resolve(
        layout: onlyInvestment,
        fallback: fallback,
        segment: null,
        interests: ['travel'],
      );

      expect(home.sections, isEmpty);
    });
  });

  group('secciones inválidas (FR-016)', () {
    test('tipos desconocidos o payload inválido se omiten y se reportan', () {
      final layout = layoutOf({
        'default': [
          banner('ok', 0),
          section('video', 'video', 1),
          section('roto', 'banner', 2, payload: {'title': 'sin subtítulo'}),
        ],
      });

      final home = resolve(layout: layout, fallback: fallback, segment: null);

      expect(ids(home), ['ok']);
      expect(home.skipped.map((s) => s.reason), [
        SkippedSection.unknownType,
        SkippedSection.invalidPayload,
      ]);
    });

    test('tipos que ninguna feature registró se omiten y se reportan', () {
      final layout = layoutOf({
        'default': [section('cuentas', 'accounts_summary', 0), banner('b', 1)],
      });

      final home = resolve(
        layout: layout,
        fallback: fallback,
        segment: null,
        canRender: (type) => type != HomeSectionType.accountsSummary,
      );

      expect(ids(home), ['b']);
      expect(
        home.skipped.single,
        const SkippedSection(
          id: 'cuentas',
          type: 'accounts_summary',
          reason: ResolveHomeLayout.notRendered,
        ),
      );
    });
  });
}
