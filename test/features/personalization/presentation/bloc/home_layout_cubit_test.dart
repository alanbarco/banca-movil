import 'dart:async';

import 'package:bi_app/core/error/failure.dart';
import 'package:bi_app/core/error/result.dart';
import 'package:bi_app/core/observability/analytics_events.dart';
import 'package:bi_app/core/sdui/home_section.dart';
import 'package:bi_app/core/session/current_user_profile.dart';
import 'package:bi_app/features/personalization/domain/entities/home_layout.dart';
import 'package:bi_app/features/personalization/domain/repositories/home_layout_repository.dart';
import 'package:bi_app/features/personalization/domain/usecases/resolve_home_layout.dart';
import 'package:bi_app/features/personalization/presentation/bloc/home_layout_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/fake_observability.dart';
import '../../personalization_fixtures.dart';

class _FakeRepository implements HomeLayoutRepository {
  final layouts = StreamController<Result<HomeLayout>>.broadcast();
  Result<void> refreshResult = const Success(null);

  @override
  HomeLayout? current;

  @override
  final HomeLayout localDefaults = layoutOf({
    'default': [banner('local', 0)],
  });

  @override
  Stream<Result<HomeLayout>> watchLayout() => layouts.stream;

  @override
  Future<Result<void>> refresh() async => refreshResult;

  void publish(HomeLayout layout) {
    current = layout;
    layouts.add(Success(layout));
  }
}

class _FakeUser implements CurrentUserProfile {
  _FakeUser(this.current);

  final _changes = StreamController<SessionUser?>.broadcast();

  @override
  SessionUser? current;

  @override
  Stream<SessionUser?> get user => _changes.stream;

  void update(SessionUser user) {
    current = user;
    _changes.add(user);
  }
}

void main() {
  late _FakeRepository repository;
  late _FakeUser user;
  late FakeFlags flags;
  late FakeObservabilityService observability;
  late HomeLayoutCubit cubit;

  final layout = layoutOf({
    'student': [
      banner('estudiante', 0),
      tip('ahorro', 1, interests: ['savings']),
      tip('viajes', 2, interests: ['travel']),
      offers('ofertas', 3, [offerItem('o1')], flag: 'offers'),
    ],
    'default': [banner('general', 0)],
  });

  setUp(() {
    repository = _FakeRepository();
    user = _FakeUser(
      const SessionUser(uid: 'u1', segment: 'student', interests: ['savings']),
    );
    flags = FakeFlags();
    observability = FakeObservabilityService();
    cubit = HomeLayoutCubit(
      repository: repository,
      resolveHomeLayout: ResolveHomeLayout(flags),
      currentUser: user,
      flags: flags,
      observability: observability,
    )..start();
  });

  tearDown(() async {
    await cubit.close();
    await repository.layouts.close();
  });

  List<String> ids() => cubit.state.sections.map((s) => s.id).toList();

  test('carga el layout del segmento con sus intereses', () async {
    expect(cubit.state.loading, isTrue);

    repository.publish(layout);
    await pumpEventQueue();

    expect(cubit.state.loading, isFalse);
    expect(ids(), ['estudiante', 'ahorro', 'ofertas']);
    expect(cubit.state.segment, 'student');
  });

  test('re-emite al publicar un layout nuevo (onConfigUpdated)', () async {
    repository.publish(layout);
    await pumpEventQueue();

    repository.publish(
      layoutOf({
        'student': [
          tip('ahorro', 0, interests: ['savings']),
          banner('estudiante', 1),
        ],
      }),
    );
    await pumpEventQueue();

    expect(ids(), ['ahorro', 'estudiante']);
  });

  test('re-emite al cambiar los intereses del cliente', () async {
    repository.publish(layout);
    await pumpEventQueue();

    user.update(
      const SessionUser(uid: 'u1', segment: 'student', interests: ['travel']),
    );
    await pumpEventQueue();

    expect(ids(), ['estudiante', 'viajes', 'ofertas']);
  });

  test('re-emite al apagar un flag', () async {
    repository.publish(layout);
    await pumpEventQueue();

    flags.turnOff('offers');
    await pumpEventQueue();

    expect(ids(), isNot(contains('ofertas')));
  });

  test('falla de personalización conserva el último layout conocido', () async {
    repository.publish(layout);
    await pumpEventQueue();

    repository.layouts.add(const Err(Failure.server()));
    await pumpEventQueue();

    expect(ids(), ['estudiante', 'ahorro', 'ofertas']);
    expect(
      observability.named(AnalyticsEvents.dataLoadError).single.parameters,
      {
        AnalyticsParams.feature: 'personalization',
        AnalyticsParams.reason: 'server',
      },
    );
  });

  test('falla sin layout previo → configuración predeterminada', () async {
    repository.layouts.add(const Err(Failure.network()));
    await pumpEventQueue();

    expect(cubit.state.loading, isFalse);
    expect(ids(), ['local']);
    expect(cubit.state.usedFallback, isTrue);
  });

  test('secciones omitidas se reportan una sola vez', () async {
    final withInvalid = layoutOf({
      'student': [banner('ok', 0), section('video', 'video', 1)],
    });

    repository.publish(withInvalid);
    await pumpEventQueue();
    user.update(
      const SessionUser(uid: 'u1', segment: 'student', interests: ['travel']),
    );
    await pumpEventQueue();

    final events = observability.named(AnalyticsEvents.sduiSectionSkipped);
    expect(events, hasLength(1));
    expect(events.single.parameters, {
      AnalyticsParams.sectionType: 'video',
      AnalyticsParams.reason: 'unknown_type',
    });
  });

  test('tipos no registrados se omiten', () async {
    await cubit.close();
    cubit = HomeLayoutCubit(
      repository: repository,
      resolveHomeLayout: ResolveHomeLayout(flags),
      currentUser: user,
      flags: flags,
      observability: observability,
      canRender: (type) => type == HomeSectionType.banner,
    )..start();

    repository.publish(layout);
    await pumpEventQueue();

    expect(ids(), ['estudiante']);
  });

  test('refresh con error registra data_load_error', () async {
    repository.refreshResult = const Err(Failure.network());

    await cubit.refresh();

    expect(observability.named(AnalyticsEvents.dataLoadError), hasLength(1));
  });
}
