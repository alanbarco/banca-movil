import 'package:bi_app/core/data/data_snapshot.dart';
import 'package:bi_app/core/error/failure.dart';
import 'package:bi_app/core/error/result.dart';
import 'package:bi_app/core/ui/widgets/stale_data_banner.dart';
import 'package:bi_app/features/fx/domain/entities/exchange_rates.dart';
import 'package:bi_app/features/fx/domain/repositories/fx_repository.dart';
import 'package:bi_app/features/fx/presentation/bloc/fx_cubit.dart';
import 'package:bi_app/features/fx/presentation/fx_texts.dart';
import 'package:bi_app/features/fx/presentation/pages/fx_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../fx_fixtures.dart';

class _MockRepository extends Mock implements FxRepository {}

void main() {
  late _MockRepository repository;

  setUp(() => repository = _MockRepository());

  void answer(Result<DataSnapshot<ExchangeRates>> result) =>
      when(() => repository.latest()).thenAnswer((_) async => result);

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider(
          create: (_) => FxCubit(repository: repository)..load(),
          child: const FxPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('muestra tasas con fecha y el monto convertido', (tester) async {
    answer(Success(DataSnapshot(data: rates, lastSyncedAt: fetchedAt)));
    await pumpPage(tester);

    expect(find.text('Tasas del 02/10/2026 · 1 USD'), findsOneWidget);
    expect(find.text('0,9200'), findsOneWidget);
    expect(find.text('92,00 EUR'), findsOneWidget);
    expect(find.text('Tasa usada: 1 USD = 0,9200 EUR'), findsOneWidget);
    expect(find.byType(StaleDataBanner), findsNothing);

    await tester.enterText(find.byKey(const Key('fx_amount')), '50');
    await tester.pump();
    expect(find.text('46,00 EUR'), findsOneWidget);

    await tester.tap(find.byTooltip(FxTexts.swap));
    await tester.pump();
    expect(find.text('54,35 USD'), findsOneWidget);
  });

  testWidgets(
    'con caché desactualizada muestra el aviso y sigue convirtiendo',
    (tester) async {
      answer(
        Success(
          DataSnapshot(data: rates, isStale: true, lastSyncedAt: fetchedAt),
        ),
      );
      await pumpPage(tester);

      expect(find.byType(StaleDataBanner), findsOneWidget);
      expect(find.textContaining(FxTexts.unavailableCause), findsOneWidget);
      expect(find.text('92,00 EUR'), findsOneWidget);
    },
  );

  testWidgets('sin caché muestra error y reintentar recupera', (tester) async {
    answer(const Err(Failure.server()));
    await pumpPage(tester);

    expect(
      find.text(FxTexts.loadError(const Failure.server())),
      findsOneWidget,
    );

    answer(Success(DataSnapshot(data: rates, lastSyncedAt: fetchedAt)));
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(find.text('92,00 EUR'), findsOneWidget);
  });

  testWidgets('monto inválido muestra el error del campo', (tester) async {
    answer(Success(DataSnapshot(data: rates, lastSyncedAt: fetchedAt)));
    await pumpPage(tester);

    await tester.enterText(find.byKey(const Key('fx_amount')), '1,2,3');
    await tester.pump();

    expect(find.text(FxTexts.invalidAmount), findsOneWidget);
  });
}
