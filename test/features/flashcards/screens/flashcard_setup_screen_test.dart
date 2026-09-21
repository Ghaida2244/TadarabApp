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

Future<void> _selectMaterialAndDifficulty(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('material-m1')));
  await tester.tap(find.byKey(const ValueKey('difficulty-easy')));
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
  testWidgets('Generate button is disabled until a material and a '
      'difficulty are both selected — Medium starts pre-selected, so only '
      'a material is needed by default', (tester) async {
    await tester.pumpWidget(
      _wrap(FakeFlashcardService(materials: [_material])),
    );
    await tester.pumpAndSettle();

    // Nothing selected yet: no material, even though Medium defaults on.
    expect(_generateButton(tester).onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('material-m1')));
    await tester.pumpAndSettle();
    // Material now selected, Medium is still selected by default: enabled.
    expect(_generateButton(tester).onPressed, isNotNull);

    // Deselecting the only selected difficulty disables it again.
    await tester.tap(find.byKey(const ValueKey('difficulty-medium')));
    await tester.pumpAndSettle();
    expect(_generateButton(tester).onPressed, isNull);

    // Picking any difficulty re-enables it.
    await tester.tap(find.byKey(const ValueKey('difficulty-easy')));
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

    expect(find.text('Reading your material...'), findsOneWidget);
    expect(find.text('Aiming for 10 cards'), findsOneWidget);
    expect(_generateButton(tester).onPressed, isNull);

    pending.complete(FlashcardGenerationResult(items: _items(10)));
    await tester.pumpAndSettle();
  });

  testWidgets('a short result (fewer items than requested) shows the limit '
      'dialog with the actual and requested counts', (tester) async {
    final service = FakeFlashcardService(
      materials: [_material],
      generationResult: FlashcardGenerationResult(items: _items(7)),
    );
    await tester.pumpWidget(_wrap(service));
    await tester.pumpAndSettle();

    await _selectMaterialAndDifficulty(tester);
    await tester.tap(find.text('Generate flashcards'));
    await tester.pumpAndSettle();

    expect(find.text('Fewer cards than asked'), findsOneWidget);
    expect(find.text('Start with these 7'), findsOneWidget);
  });

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
