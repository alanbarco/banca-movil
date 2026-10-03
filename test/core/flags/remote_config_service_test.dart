import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bi_app/core/flags/remote_config_service.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fake_observability.dart';

class _MockRemoteConfig extends Mock implements FirebaseRemoteConfig {}

/// Sirve el asset real de defaults desde disco.
class _DiskBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    final bytes = await File(key).readAsBytes();
    return ByteData.sublistView(bytes);
  }
}

void main() {
  late _MockRemoteConfig remote;
  late FakeObservabilityService observability;
  late StreamController<RemoteConfigUpdate> realtime;
  late RemoteConfigService service;
  final values = <String, String>{};

  setUpAll(() {
    registerFallbackValue(
      RemoteConfigSettings(
        fetchTimeout: Duration.zero,
        minimumFetchInterval: Duration.zero,
      ),
    );
  });

  setUp(() {
    remote = _MockRemoteConfig();
    observability = FakeObservabilityService();
    realtime = StreamController<RemoteConfigUpdate>.broadcast();
    values.clear();

    when(() => remote.setDefaults(any())).thenAnswer((invocation) async {
      final defaults =
          invocation.positionalArguments.first as Map<String, dynamic>;
      values.addAll(defaults.cast<String, String>());
    });
    when(() => remote.setConfigSettings(any())).thenAnswer((_) async {});
    when(() => remote.fetchAndActivate()).thenAnswer((_) async => true);
    when(() => remote.activate()).thenAnswer((_) async => true);
    when(() => remote.onConfigUpdated).thenAnswer((_) => realtime.stream);
    when(() => remote.getString(any())).thenAnswer(
      (invocation) => values[invocation.positionalArguments.first] ?? '',
    );

    service = RemoteConfigService(
      observability: observability,
      remoteConfig: remote,
      bundle: _DiskBundle(),
    );
  });

  tearDown(() async {
    await service.dispose();
    await realtime.close();
  });

  test('carga los defaults del asset como valores iniciales', () async {
    await service.initialize();

    expect(values.keys, containsAll(RemoteConfigKeys.all));
    final fx = service.getJson(RemoteConfigKeys.fxConfig);
    expect(fx['baseUrl'], 'https://api.frankfurter.dev/v1');
    expect(service.localDefault(RemoteConfigKeys.terms)?['version'], '2026-10');
  });

  test('un fetch fallido no rompe el arranque y se reporta', () async {
    when(() => remote.fetchAndActivate()).thenThrow(Exception('sin red'));

    await service.initialize();

    expect(service.getJson(RemoteConfigKeys.terms)['schemaVersion'], 1);
    expect(observability.errors, hasLength(1));
  });

  test('JSON inválido o versión futura usan el último válido', () async {
    await service.initialize();
    values[RemoteConfigKeys.terms] = jsonEncode({
      'schemaVersion': 1,
      'version': '2026-11',
      'url': 'https://x.test',
    });
    expect(service.getJson(RemoteConfigKeys.terms)['version'], '2026-11');

    values[RemoteConfigKeys.terms] = '{roto';
    expect(service.getJson(RemoteConfigKeys.terms)['version'], '2026-11');

    values[RemoteConfigKeys.terms] = jsonEncode({
      'schemaVersion': 2,
      'version': '2027-01',
    });
    expect(service.getJson(RemoteConfigKeys.terms)['version'], '2026-11');
    expect(observability.errors, hasLength(2));
  });

  test('actualización en tiempo real activa y notifica las claves', () async {
    await service.initialize();
    final next = service.updates.first;

    realtime.add(RemoteConfigUpdate({RemoteConfigKeys.homeLayout}));

    expect(await next, {RemoteConfigKeys.homeLayout});
    verify(() => remote.activate()).called(1);
  });
}
