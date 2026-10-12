import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/features/flashcards/screens/flashcard_setup_screen.dart'
    show kFlashcardLoadingConfig;
import 'package:tadarab_app/models/enums.dart';
import 'package:tadarab_app/screens/quiz/quiz_setup_screen.dart'
    show kQuizLoadingConfig;
import 'package:tadarab_app/widgets/generation_loading_overlay.dart';

void main() {
  // Short, test-controlled durations — NOTE 8 requires the real 45s/5s
  // never be waited on for real; these are passed explicitly rather than
  // relying on the (much longer) production defaults.
  const rotation = Duration(seconds: 1);
  const longWait = Duration(seconds: 5);

  Future<void> pump(
    WidgetTester tester, {
    required GenerationLoadingConfig config,
    String fixedLine = 'Aiming for 10 questions · easy',
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            GenerationLoadingOverlay(
              config: config,
              fixedLine: fixedLine,
              rotationInterval: rotation,
              longWaitThreshold: longWait,
            ),
          ],
        ),
      ),
    );
  }

  // A single `tester.pump(largeDuration)` call only samples one frame at
  // the far end of that jump — AnimatedSwitcher's internal "the outgoing
  // child's animation reached dismissed" status listener needs the
  // scheduler to actually tick through intermediate frames to fire, so a
  // big one-shot jump can leave a fully-faded (but still mounted) old
  // child behind. Stepping in small increments gives it those
  // intermediate frames, matching how a real clock would drive it.
  Future<void> advance(WidgetTester tester, Duration total) async {
    const step = Duration(milliseconds: 50);
    var remaining = total;
    while (remaining > Duration.zero) {
      final next = remaining < step ? remaining : step;
      await tester.pump(next);
      remaining -= next;
    }
  }

  testWidgets(
    'Quiz wording: rotates the exact sentence and tip, with the fixed '
    'line always visible',
    (tester) async {
      await pump(tester, config: kQuizLoadingConfig);

      expect(find.text('Preparing your quiz...'), findsOneWidget);
      expect(find.text('Try to answer before you look at the options.'), findsNothing);
      expect(find.text('Aiming for 10 questions · easy'), findsOneWidget);

      // First step crosses the first rotation boundary with ~500ms to
      // spare for the fade to finish; every later step just adds one
      // full `rotation` again, preserving that same ~500ms of settle
      // time after each new boundary it crosses (landing safely
      // mid-interval, never exactly back-to-back with the next one).
      await advance(tester, rotation + const Duration(milliseconds: 500));
      expect(find.text('Try to answer before you look at the options.'), findsOneWidget);
      expect(find.text('Preparing your quiz...'), findsNothing);

      await advance(tester, rotation);
      expect(find.text('Preparing your quiz...'), findsOneWidget);
      expect(find.text('Try to answer before you look at the options.'), findsNothing);
    },
  );

  testWidgets(
    'Flashcards wording: rotates the exact sentence and tip',
    (tester) async {
      await pump(
        tester,
        config: kFlashcardLoadingConfig,
        fixedLine: 'Aiming for 10 flashcards · easy',
      );

      expect(find.text('Preparing your flashcards...'), findsOneWidget);

      await advance(tester, rotation + const Duration(milliseconds: 500));
      expect(
        find.text('Say the answer out loud before you flip the card.'),
        findsOneWidget,
      );
      expect(find.text('Preparing your flashcards...'), findsNothing);
    },
  );

  testWidgets(
    'after the long-wait threshold, the rotation is replaced for good',
    (tester) async {
      await pump(tester, config: kQuizLoadingConfig);

      // Advance well past the long-wait threshold, through several
      // rotation ticks — a real elapsed-time check, not a single lucky
      // frame.
      await advance(tester, longWait + const Duration(seconds: 1, milliseconds: 500));

      expect(
        find.text("Thanks for your patience. We're still putting it together."),
        findsOneWidget,
      );
      expect(find.text('Preparing your quiz...'), findsNothing);
      expect(find.text('Try to answer before you look at the options.'), findsNothing);

      // Stays — advancing further through more rotation-interval-sized
      // steps never flips back to the sentence/tip.
      await advance(tester, rotation * 3 + const Duration(milliseconds: 500));
      expect(
        find.text("Thanks for your patience. We're still putting it together."),
        findsOneWidget,
      );
      expect(find.text('Preparing your quiz...'), findsNothing);
      expect(find.text('Try to answer before you look at the options.'), findsNothing);
    },
  );

  group('buildGenerationFixedLine', () {
    test('one difficulty: lists it alone', () {
      expect(
        buildGenerationFixedLine(
          count: 10,
          noun: 'questions',
          difficulties: {DifficultyLevel.easy},
        ),
        'Aiming for 10 questions · easy',
      );
    });

    test('two difficulties: always in easy/medium/hard order, regardless '
        'of selection order', () {
      expect(
        buildGenerationFixedLine(
          count: 10,
          noun: 'questions',
          // Selected hard first, then easy — set iteration order must
          // not leak into the rendered line.
          difficulties: {DifficultyLevel.hard, DifficultyLevel.easy},
        ),
        'Aiming for 10 questions · easy, hard',
      );
    });

    test('three difficulties: easy, medium, hard', () {
      expect(
        buildGenerationFixedLine(
          count: 10,
          noun: 'questions',
          difficulties: {
            DifficultyLevel.medium,
            DifficultyLevel.hard,
            DifficultyLevel.easy,
          },
        ),
        'Aiming for 10 questions · easy, medium, hard',
      );
    });

    test('uses the caller\'s noun exactly — "flashcards" for Flashcards, '
        '"questions" for Quiz', () {
      expect(
        buildGenerationFixedLine(
          count: 10,
          noun: 'flashcards',
          difficulties: {DifficultyLevel.easy},
        ),
        'Aiming for 10 flashcards · easy',
      );
    });

    test('a count of 1 renders without crashing (unreachable today since '
        'the real minimum is 5, but must not throw if it ever happens)', () {
      expect(
        buildGenerationFixedLine(
          count: 1,
          noun: 'questions',
          difficulties: {DifficultyLevel.easy},
        ),
        'Aiming for 1 questions · easy',
      );
    });
  });

  testWidgets(
    'the fixed line reflects the actual chosen settings, including the '
    'new Easy/10 defaults',
    (tester) async {
      await pump(
        tester,
        config: kQuizLoadingConfig,
        fixedLine: buildGenerationFixedLine(
          count: 10,
          noun: 'questions',
          difficulties: {DifficultyLevel.easy},
        ),
      );

      expect(find.text('Aiming for 10 questions · easy'), findsOneWidget);
    },
  );

  testWidgets(
    'the Quiz and Flashcards overlays render the exact same widget types '
    'in the exact same order — they differ only in text content',
    (tester) async {
      List<Type> typeSequence(WidgetTester tester) {
        final root = tester.element(find.byType(GenerationLoadingOverlay));
        final types = <Type>[];
        void visit(Element element) {
          types.add(element.widget.runtimeType);
          element.visitChildren(visit);
        }
        visit(root);
        return types;
      }

      await pump(
        tester,
        config: kQuizLoadingConfig,
        fixedLine: buildGenerationFixedLine(
          count: 10,
          noun: 'questions',
          difficulties: {DifficultyLevel.easy},
        ),
      );
      final quizTypes = typeSequence(tester);

      await pump(
        tester,
        config: kFlashcardLoadingConfig,
        fixedLine: buildGenerationFixedLine(
          count: 10,
          noun: 'flashcards',
          difficulties: {DifficultyLevel.easy},
        ),
      );
      final flashcardTypes = typeSequence(tester);

      expect(quizTypes, flashcardTypes);
      // Not a vacuous pass: real structure is actually being walked.
      expect(quizTypes, contains(CircularProgressIndicator));
      expect(quizTypes, contains(AnimatedSwitcher));
    },
  );

  testWidgets(
    'no long-wait message appears if the overlay is removed before the '
    'threshold (generation finished early) — and no error is thrown',
    (tester) async {
      await pump(tester, config: kQuizLoadingConfig);

      // Generation "finishes" well before the long-wait threshold —
      // simulated by replacing the tree with one that no longer has the
      // overlay in it (same as a setup screen's `if (_generating) ...`
      // conditional turning false), which disposes it.
      await advance(tester, const Duration(seconds: 2));
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));

      expect(
        find.text("Thanks for your patience. We're still putting it together."),
        findsNothing,
      );
      expect(tester.takeException(), isNull);

      // Advancing the clock well past where the long-wait timer would
      // have fired must not throw (no setState after dispose) and must
      // not resurrect the overlay.
      await advance(tester, longWait + const Duration(seconds: 5));
      expect(tester.takeException(), isNull);
      expect(
        find.text("Thanks for your patience. We're still putting it together."),
        findsNothing,
      );
    },
  );

  testWidgets(
    'disposing before any timer fires cancels both timers cleanly',
    (tester) async {
      await pump(tester, config: kQuizLoadingConfig);

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      expect(tester.takeException(), isNull);

      // No pending timers left behind — flutter_test fails the test on
      // teardown if any real Timer is still pending, so this passing at
      // all (and cleanly, with no later exception) is itself the proof.
      await advance(tester, longWait + const Duration(seconds: 5));
      expect(tester.takeException(), isNull);
    },
  );
}
