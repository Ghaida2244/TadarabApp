import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/features/flashcards/screens/flashcard_setup_screen.dart';
import 'package:tadarab_app/models/enums.dart';
import 'package:tadarab_app/models/flashcard.dart';
import 'package:tadarab_app/models/study_material.dart';
import 'package:tadarab_app/services/flashcard_service.dart';
import 'package:tadarab_app/widgets/app_button.dart';

import '../../../helpers/fake_flashcard_service.dart';

final _material = StudyMaterial(
  materialId: 'm1',
  title: 'Lecture 1 - Introduction',
  type: 'pptx',
  document: 'materials/m1.pptx',
  courseId: 'course-1',
  extractedText: '[Slide 1: Introduction]\nSample extracted text for tests.',
);

Widget _wrap(FakeFlashcardService service) {
  return MaterialApp(
    home: FlashcardSetupScreen(
      uid: 'uid-1',
      courseId: 'course-1',
      email: 'student@example.com',
      service: service,
    ),
  );
}

AppButton _generateButton(WidgetTester tester) => tester.widget<AppButton>(
  find.byWidgetPredicate(
    (w) => w is AppButton && w.label == 'Generate flashcards',
  ),
);

// Easy is selected by default (NOTE 13a), so selecting a material alone
// already satisfies both requirements for Generate to enable — no
// separate difficulty tap needed any more.
Future<void> _selectMaterialAndDifficulty(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('material-m1')));
  await tester.pumpAndSettle();
}

List<FlashcardGenerationItem> _items(int count) => List.generate(
  count,
  (i) => FlashcardGenerationItem(
    frontText: 'Q$i',
    backText: 'A$i',
    sourceLocation: 'Slide $i',
    difficulty: DifficultyLevel.easy,
  ),
);

List<Flashcard> _flashcards(int count) => List.generate(
  count,
  (i) => Flashcard(
    flashcardId: 'card-$i',
    frontText: 'Q$i',
    backText: 'A$i',
    reviewStatus: null,
    sourceLocation: 'Slide $i',
    sessionId: 'session-new',
    cardIndex: i,
  ),
);

void main() {
  testWidgets(
    'NOTE 13a/13b: starts with Easy selected and the count at 10',
    (tester) async {
      await tester.pumpWidget(
        _wrap(FakeFlashcardService(materials: [_material])),
      );
      await tester.pumpAndSettle();

      expect(find.text('10'), findsOneWidget);

      final easyButton = tester.widget<Container>(
        find
            .descendant(
              of: find.byKey(const ValueKey('difficulty-easy')),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = easyButton.decoration! as BoxDecoration;
      expect(decoration.color, isNot(Colors.white)); // navy-filled, selected
    },
  );

  testWidgets('Generate button is disabled until a material and a '
      'difficulty are both selected — Easy starts pre-selected, so only '
      'a material is needed by default', (tester) async {
    await tester.pumpWidget(
      _wrap(FakeFlashcardService(materials: [_material])),
    );
    await tester.pumpAndSettle();

    // Nothing selected yet: no material, even though Easy defaults on.
    expect(_generateButton(tester).onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('material-m1')));
    await tester.pumpAndSettle();
    // Material now selected, Easy is still selected by default: enabled.
    expect(_generateButton(tester).onPressed, isNotNull);

    // Deselecting the only selected difficulty disables it again.
    await tester.tap(find.byKey(const ValueKey('difficulty-easy')));
    await tester.pumpAndSettle();
    expect(_generateButton(tester).onPressed, isNull);

    // Picking any difficulty re-enables it.
    await tester.tap(find.byKey(const ValueKey('difficulty-medium')));
    await tester.pumpAndSettle();
    expect(_generateButton(tester).onPressed, isNotNull);
  });

  testWidgets('tapping Generate shows the Generating overlay with the '
      'aimed-for count, before the Worker call resolves', (tester) async {
    final pending = Completer<FlashcardGenerationResult>();
    final service = FakeFlashcardService(
      materials: [_material],
      pendingGeneration: pending,
      flashcardsBySessionId: {'session-new': _flashcards(10)},
    );
    await tester.pumpWidget(_wrap(service));
    await tester.pumpAndSettle();

    await _selectMaterialAndDifficulty(tester);
    await tester.tap(find.text('Generate flashcards'));
    await tester.pump();

    expect(find.text('Preparing your flashcards...'), findsOneWidget);
    // Easy is the only selected difficulty here (the default, untouched
    // by _selectMaterialAndDifficulty) — see buildGenerationFixedLine.
    expect(find.text('Aiming for 10 flashcards · easy'), findsOneWidget);
    expect(_generateButton(tester).onPressed, isNull);

    pending.complete(
      FlashcardGenerationResult(items: _items(10), requestedCount: 10),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('a short result (fewer items than requested) shows the limit '
      'dialog with the actual and requested counts', (tester) async {
    final service = FakeFlashcardService(
      materials: [_material],
      generationResult: FlashcardGenerationResult(
        items: _items(7),
        requestedCount: 10,
      ),
    );
    await tester.pumpWidget(_wrap(service));
    await tester.pumpAndSettle();

    await _selectMaterialAndDifficulty(tester);
    await tester.tap(find.text('Generate flashcards'));
    await tester.pumpAndSettle();

    expect(find.text('Fewer cards than asked'), findsOneWidget);
    expect(find.text('Start with these 7'), findsOneWidget);
  });

  testWidgets(
    "shows the Worker's note in a SnackBar when generation succeeds with "
    'one, even at the full requested count',
    (tester) async {
      final service = FakeFlashcardService(
        materials: [_material],
        flashcardsBySessionId: {'session-new': _flashcards(10)},
        generationResult: FlashcardGenerationResult(
          items: _items(10),
          requestedCount: 10,
          note: 'An uneven split of difficulty levels was used.',
        ),
      );
      await tester.pumpWidget(_wrap(service));
      await tester.pumpAndSettle();

      await _selectMaterialAndDifficulty(tester);
      await tester.tap(find.text('Generate flashcards'));
      await tester.pump();
      await tester.pump();

      expect(
        find.text('An uneven split of difficulty levels was used.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'shows no SnackBar when the count matches and there is no note',
    (tester) async {
      final service = FakeFlashcardService(
        materials: [_material],
        flashcardsBySessionId: {'session-new': _flashcards(10)},
        generationResult: FlashcardGenerationResult(
          items: _items(10),
          requestedCount: 10,
        ),
      );
      await tester.pumpWidget(_wrap(service));
      await tester.pumpAndSettle();

      await _selectMaterialAndDifficulty(tester);
      await tester.tap(find.text('Generate flashcards'));
      await tester.pump();
      await tester.pump();

      expect(find.byType(SnackBar), findsNothing);
    },
  );

  testWidgets('a generation failure shows a retry-able generic-failure '
      'message', (tester) async {
    final service = FakeFlashcardService(
      materials: [_material],
      generationError: Exception('boom'),
    );
    await tester.pumpWidget(_wrap(service));
    await tester.pumpAndSettle();

    await _selectMaterialAndDifficulty(tester);
    await tester.tap(find.text('Generate flashcards'));
    await tester.pumpAndSettle();

    expect(find.text(kFlashcardGenericFailureMessage), findsOneWidget);
  });
}
