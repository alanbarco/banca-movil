import 'package:bi_app/core/storage/local_storage.dart';
import 'package:bi_app/core/ui/balance_visibility_cubit.dart';
import 'package:bi_app/core/ui/widgets/money_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('MoneyText.format', () {
    test('formatea centavos en USD (es_EC)', () {
      expect(MoneyText.format(125000), r'$1.250,00');
      expect(MoneyText.format(5), r'$0,05');
      expect(MoneyText.format(-15000), r'-$150,00');
    });

    test('showSign antepone + o −', () {
      expect(MoneyText.format(4000, showSign: true), r'+$40,00');
      expect(MoneyText.format(-4000, showSign: true), r'−$40,00');
    });

    test('etiqueta accesible legible', () {
      expect(MoneyText.semanticsFor(125000), '1.250,00 dólares');
      expect(
        MoneyText.semanticsFor(-4000, showSign: true),
        'menos 40,00 dólares',
      );
      expect(MoneyText.semanticsFor(4000, showSign: true), 'más 40,00 dólares');
    });
  });

  group('BalanceVisibilityCubit + MoneyText', () {
    late LocalStorage storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = await LocalStorage.create();
    });

    Widget wrap(BalanceVisibilityCubit cubit) => MaterialApp(
      home: BlocProvider.value(
        value: cubit,
        child: const Scaffold(body: MoneyText(125000)),
      ),
    );

    testWidgets('muestra el monto y lo oculta al alternar', (tester) async {
      final handle = tester.ensureSemantics();
      final cubit = BalanceVisibilityCubit(storage);

      await tester.pumpWidget(wrap(cubit));
      expect(find.text(r'$1.250,00'), findsOneWidget);
      expect(find.bySemanticsLabel('1.250,00 dólares'), findsOneWidget);

      await cubit.toggle();
      await tester.pump();
      expect(find.text(MoneyText.hiddenMask), findsOneWidget);
      expect(find.bySemanticsLabel(MoneyText.hiddenLabel), findsOneWidget);

      await cubit.close();
      handle.dispose();
    });

    test('recuerda la preferencia entre instancias', () async {
      final first = BalanceVisibilityCubit(storage);
      expect(first.state, isFalse);
      await first.setHidden(hidden: true);

      final second = BalanceVisibilityCubit(storage);
      expect(second.state, isTrue);
      expect(storage.getBool(BalanceVisibilityCubit.storageKey), isTrue);
    });
  });

  group('LocalStorage', () {
    test('json, string, bool y remove', () async {
      SharedPreferences.setMockInitialValues({'bad': 'no-json'});
      final storage = await LocalStorage.create();

      await storage.setJson('k', {'a': 1});
      await storage.setString('s', 'v');
      await storage.setBool('b', value: true);

      expect(storage.getJson('k'), {'a': 1});
      expect(storage.getJson('bad'), isNull);
      expect(storage.getJson('missing'), isNull);
      expect(storage.getString('s'), 'v');
      expect(storage.getBool('b'), isTrue);

      await storage.remove('s');
      expect(storage.getString('s'), isNull);
    });
  });
}
