import 'dart:async';

import 'package:bi_app/core/flags/feature_flags.dart';
import 'package:bi_app/core/flags/flag_keys.dart';
import 'package:bi_app/core/flags/remote_config_feature_flag_service.dart';
import 'package:bi_app/core/flags/remote_config_service.dart';
import 'package:bi_app/core/observability/analytics_events.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fake_observability.dart';

class _MockRemoteConfigService extends Mock implements RemoteConfigService {}

Map<String, dynamic> _flagsJson(Map<String, Object> flags) => {
  'schemaVersion': 1,
  'flags': flags,
};

void main() {
  group('FeatureFlags', () {
    final flags = FeatureFlags.fromJson(
      _flagsJson({
        'fx_service': {'enabled': true, 'segments': <String>[]},
        'offers': {
          'enabled': true,
          'segments': ['student', 'professional'],
        },
        'demo_fault_panel': {'enabled': false, 'segments': <String>[]},
      }),
    );

    test('segments vacío aplica a todos los segmentos', () {
      expect(flags.isEnabled('fx_service', segment: 'student'), isTrue);
      expect(flags.isEnabled('fx_service', segment: 'entrepreneur'), isTrue);
      expect(flags.isEnabled('fx_service'), isTrue);
    });

    test('segments restringe a los segmentos listados', () {
      expect(flags.isEnabled('offers', segment: 'student'), isTrue);
      expect(flags.isEnabled('offers', segment: 'entrepreneur'), isFalse);
      expect(flags.isEnabled('offers'), isFalse);
    });

    test('flag deshabilitado nunca aplica', () {
      expect(flags.isEnabled('demo_fault_panel', segment: 'student'), isFalse);
    });

    test('flag ausente usa el default local', () {
      final defaults = FeatureFlags.fromJson(
        _flagsJson({
          'push_opt_in_prompt': {'enabled': true, 'segments': <String>[]},
        }),
      );

      expect(flags.isEnabled('push_opt_in_prompt', defaults: defaults), isTrue);
    });

    test('flag ausente sin default queda apagado', () {
      expect(flags.isEnabled('desconocido'), isFalse);
    });

    test('ignora entradas mal formadas sin descartar las demás', () {
      final parsed = FeatureFlags.fromJson(
        _flagsJson({
          'a': {'enabled': 'yes'},
          'b': 'texto',
          'c': {'enabled': true},
        }),
      );

      expect(parsed.rules.keys, ['c']);
      expect(FeatureFlags.fromJson(const {}).rules, isEmpty);
    });
  });

  group('RemoteConfigFeatureFlagService', () {
    late _MockRemoteConfigService remoteConfig;
    late FakeObservabilityService observability;
    late StreamController<Set<String>> updates;

    setUp(() {
      remoteConfig = _MockRemoteConfigService();
      observability = FakeObservabilityService();
      updates = StreamController<Set<String>>.broadcast();
      when(() => remoteConfig.updates).thenAnswer((_) => updates.stream);
      when(
        () => remoteConfig.localDefault(RemoteConfigKeys.featureFlags),
      ).thenReturn(
        _flagsJson({
          FlagKeys.pushOptInPrompt: {'enabled': true, 'segments': <String>[]},
        }),
      );
    });

    tearDown(() => updates.close());

    test('usa remoto y cae al default local si el flag no existe', () {
      when(
        () => remoteConfig.getJson(RemoteConfigKeys.featureFlags),
      ).thenReturn(
        _flagsJson({
          FlagKeys.fxService: {'enabled': false, 'segments': <String>[]},
        }),
      );
      final service = RemoteConfigFeatureFlagService(
        remoteConfig: remoteConfig,
        observability: observability,
      );

      expect(service.isEnabled(FlagKeys.fxService), isFalse);
      expect(service.isEnabled(FlagKeys.pushOptInPrompt), isTrue);
      expect(service.isEnabled(FlagKeys.offers), isFalse);
    });

    test('recarga y notifica cuando cambia feature_flags', () async {
      var enabled = false;
      when(
        () => remoteConfig.getJson(RemoteConfigKeys.featureFlags),
      ).thenAnswer(
        (_) => _flagsJson({
          FlagKeys.fxService: {'enabled': enabled, 'segments': <String>[]},
        }),
      );
      final service = RemoteConfigFeatureFlagService(
        remoteConfig: remoteConfig,
        observability: observability,
      );
      expect(service.isEnabled(FlagKeys.fxService), isFalse);

      final changed = service.changes.first;
      enabled = true;
      updates
        ..add({RemoteConfigKeys.homeLayout})
        ..add({RemoteConfigKeys.featureFlags});
      await changed;

      expect(service.isEnabled(FlagKeys.fxService), isTrue);
      await service.dispose();
    });

    test('registra feature_flag_evaluated solo cuando cambia el valor', () {
      when(
        () => remoteConfig.getJson(RemoteConfigKeys.featureFlags),
      ).thenReturn(
        _flagsJson({
          FlagKeys.fxService: {'enabled': true, 'segments': <String>[]},
        }),
      );
      final service = RemoteConfigFeatureFlagService(
        remoteConfig: remoteConfig,
        observability: observability,
      );

      service
        ..isEnabled(FlagKeys.fxService)
        ..isEnabled(FlagKeys.fxService)
        ..isEnabled(FlagKeys.fxService);

      final events = observability.named(AnalyticsEvents.featureFlagEvaluated);
      expect(events, hasLength(1));
      expect(events.single.parameters, {'flag': 'fx_service', 'enabled': true});
    });
  });
}
