import 'package:bi_app/core/error/failure.dart';
import 'package:bi_app/core/error/result.dart';
import 'package:bi_app/features/auth/domain/entities/interest.dart';
import 'package:bi_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:bi_app/features/auth/domain/usecases/update_interests.dart';
import 'package:bi_app/features/auth/presentation/auth_texts.dart';
import 'package:bi_app/features/auth/presentation/widgets/edit_interests_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepository extends Mock implements AuthRepository {}

void main() {
  group('UpdateInterests', () {
    late _MockRepository repository;

    setUp(() {
      repository = _MockRepository();
      when(
        () => repository.updateInterests(any()),
      ).thenAnswer((_) async => const Success(null));
    });

    test('valida 1–5 intereses sin repetir antes de guardar', () async {
      final update = UpdateInterests(repository);

      expect(
        await update(const []),
        const Err<void>(Failure.validation('interests')),
      );
      expect(
        await update(const [Interest.travel, Interest.travel]),
        const Err<void>(Failure.validation('interests')),
      );
      expect((await update(const [Interest.travel])).isSuccess, isTrue);
      verify(() => repository.updateInterests([Interest.travel])).called(1);
    });
  });

  group('EditInterestsSheet', () {
    late List<List<Interest>> saved;
    late Result<void> saveResult;

    setUp(() {
      saved = [];
      saveResult = const Success(null);
    });

    Future<void> pump(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditInterestsSheet(
              initial: const [Interest.savings],
              onSave: (interests) async {
                saved.add(interests);
                return saveResult;
              },
            ),
          ),
        ),
      );
    }

    FilledButton saveButton(WidgetTester tester) =>
        tester.widget<FilledButton>(find.byType(FilledButton));

    testWidgets('sin cambios no permite guardar', (tester) async {
      await pump(tester);

      expect(saveButton(tester).onPressed, isNull);
    });

    testWidgets('sin intereses muestra el motivo y no permite guardar', (
      tester,
    ) async {
      await pump(tester);

      await tester.tap(find.text(Interest.savings.label));
      await tester.pump();

      expect(find.text(AuthTexts.fieldError('interests')), findsOneWidget);
      expect(saveButton(tester).onPressed, isNull);
    });

    testWidgets('guarda la nueva selección', (tester) async {
      await pump(tester);

      await tester.tap(find.text(Interest.travel.label));
      await tester.pump();
      await tester.tap(find.text('Guardar'));
      await tester.pump();

      expect(saved.single, [Interest.savings, Interest.travel]);
    });

    testWidgets('error al guardar se muestra y permite reintentar', (
      tester,
    ) async {
      saveResult = const Err(Failure.network());
      await pump(tester);

      await tester.tap(find.text(Interest.travel.label));
      await tester.pump();
      await tester.tap(find.text('Guardar'));
      await tester.pump();

      expect(
        find.text(AuthTexts.forFailure(const Failure.network())),
        findsOneWidget,
      );
      expect(saveButton(tester).onPressed, isNotNull);
    });
  });
}
