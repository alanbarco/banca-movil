import 'dart:async';

import 'package:bi_app/core/error/failure.dart';
import 'package:bi_app/core/error/result.dart';
import 'package:bi_app/core/fault_injection/fault_config.dart';
import 'package:bi_app/core/fault_injection/fault_runner.dart';
import 'package:bi_app/features/personalization/data/datasources/home_layout_remote_config_datasource.dart';
import 'package:bi_app/features/personalization/data/repositories/home_layout_repository_impl.dart';
import 'package:bi_app/features/personalization/domain/entities/home_layout.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fake_observability.dart';
import '../personalization_fixtures.dart';

class _MockDatasource extends Mock
    implements HomeLayoutRemoteConfigDatasource {}

class _Faults implements FaultConfigSource {
  FaultConfig config = FaultConfig.normal;

  @override
  FaultConfig configFor(FaultTarget target) =>
      target == FaultTarget.personalization ? config : FaultConfig.normal;
}

void main() {
  late _MockDatasource datasource;
  late StreamController<void> changes;
  late _Faults faults;
  late HomeLayoutRepositoryImpl repository;

  final remote = layoutJson({
    'student': [banner('remoto', 0)],
  });
  final local = layoutJson({
    'default': [banner('local', 0)],
  });

  setUp(() {
    datasource = _MockDatasource();
    changes = StreamController<void>.broadcast();
    faults = _Faults();
    when(() => datasource.read()).thenReturn(remote);
    when(() => datasource.localDefaults()).thenReturn(local);
    when(() => datasource.changes).thenAnswer((_) => changes.stream);
    repository = HomeLayoutRepositoryImpl(
      datasource: datasource,
      faults: FaultRunner(faults),
      observability: FakeObservabilityService(),
    );
  });

  tearDown(() => changes.close());

  List<String>? idsOf(Result<HomeLayout> result, String segment) => result
      .valueOrNull
      ?.forSegment(segment)
      ?.sections
      .map((s) => s.id)
      .toList();

  test('entrega el layout vigente y lo guarda como current', () async {
    final first = await repository.watchLayout().first;

    expect(idsOf(first, 'student'), ['remoto']);
    expect(repository.current, first.valueOrNull);
  });

  test('re-emite cuando el banco publica un home_layout nuevo', () async {
    final received = <List<String>?>[];
    final subscription = repository.watchLayout().listen(
      (r) => received.add(idsOf(r, 'student')),
    );
    await pumpEventQueue();

    when(() => datasource.read()).thenReturn(
      layoutJson({
        'student': [banner('nuevo', 0)],
      }),
    );
    changes.add(null);
    await pumpEventQueue();

    expect(received, [
      ['remoto'],
      ['nuevo'],
    ]);
    await subscription.cancel();
  });

  test('defaults locales disponibles siempre', () {
    expect(
      repository.localDefaults.forSegment('cualquiera')!.sections.single.id,
      'local',
    );
  });

  test('segmentos mal formados se ignoran sin afectar a los demás', () async {
    when(() => datasource.read()).thenReturn({
      'schemaVersion': 1,
      'segments': {
        'student': 'roto',
        'default': {
          'sections': [banner('ok', 0)],
        },
      },
    });

    final layout = (await repository.watchLayout().first).valueOrNull!;

    expect(layout.segments.keys, ['default']);
  });

  test('simulador en error → Err y el stream sigue escuchando', () async {
    faults.config = const FaultConfig(mode: FaultMode.error);
    final received = <Result<HomeLayout>>[];
    final subscription = repository.watchLayout().listen(received.add);
    await pumpEventQueue();

    faults.config = FaultConfig.normal;
    changes.add(null);
    await pumpEventQueue();

    expect(received.first.failureOrNull, const Failure.server());
    expect(idsOf(received.last, 'student'), ['remoto']);
    expect(repository.current, isNotNull);
    await subscription.cancel();
  });

  test('refresh sin red → network', () async {
    when(() => datasource.refresh()).thenThrow(
      FirebaseException(plugin: 'firebase_remote_config', code: 'internal'),
    );

    final result = await repository.refresh();

    expect(result.failureOrNull, const Failure.network());
  });

  test('refresh correcto', () async {
    when(() => datasource.refresh()).thenAnswer((_) async {});

    expect((await repository.refresh()).isSuccess, isTrue);
  });
}
