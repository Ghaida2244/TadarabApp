import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/screens/profile/about_document_screen.dart';
import 'package:tadarab_app/screens/profile/content/about_content.dart';
import 'package:tadarab_app/screens/profile/learning_guide_screen.dart';
import 'package:tadarab_app/screens/profile/content/learning_guide_content.dart';
import 'package:tadarab_app/features/flashcards/logic/flashcard_logic.dart';
import 'package:tadarab_app/services/quiz_session_service.dart';
import 'package:tadarab_app/utils/rank.dart';

void main() {
  Future<void> pumpDocument(WidgetTester tester, AboutDocument document) async {
    tester.view.physicalSize = const Size(412, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(home: AboutDocumentScreen(document: document)),
    );
    await tester.pumpAndSettle();
  }

  group('classic documents', () {
    for (final document in [
      kAboutUsDocument,
      kPrivacyPolicyDocument,
      kTermsOfUseDocument,
    ]) {
      testWidgets('${document.title} renders its title and every block', (
        tester,
      ) async {
        await pumpDocument(tester, document);

        expect(find.text(document.title), findsOneWidget);
        for (final block in document.blocks) {
          expect(find.text(block.heading), findsOneWidget);
          expect(find.text(block.body), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('the contact address is present, as the design states it', (
      tester,
    ) async {
      await pumpDocument(tester, kAboutUsDocument);

      expect(
        find.textContaining('tadarabapp@gmail.com'),
        findsOneWidget,
      );
    });

    testWidgets('a back chip returns', (tester) async {
      await pumpDocument(tester, kAboutUsDocument);

      expect(find.bySemanticsLabel('Back'), findsOneWidget);
    });
  });

  group('team-chosen copy', () {
    // The generic tests above would pass against any wording, since they
    // read the same constants the screens do. These pin the specific
    // decisions the team made, so a future edit can't silently revert them.

    AboutBlock blockNamed(AboutDocument document, String heading) =>
        document.blocks.firstWhere((b) => b.heading == heading);

    test('every heading is title-case', () {
      // "How it helps" was renamed to "How It Helps"; nothing should drift
      // back to sentence case.
      const smallWords = {'a', 'an', 'and', 'the', 'of', 'to', 'in', 'us'};
      for (final document in [
        kAboutUsDocument,
        kPrivacyPolicyDocument,
        kTermsOfUseDocument,
      ]) {
        for (final block in document.blocks) {
          for (final word in block.heading.split(' ')) {
            if (smallWords.contains(word.toLowerCase())) continue;
            expect(
              word[0],
              word[0].toUpperCase(),
              reason: '"${block.heading}" in ${document.title}',
            );
          }
        }
      }
    });

    test('uses American spelling', () {
      for (final document in [
        kAboutUsDocument,
        kPrivacyPolicyDocument,
        kTermsOfUseDocument,
      ]) {
        for (final block in document.blocks) {
          for (final british in ['organised', 'colour', 'behaviour']) {
            expect(
              block.body.toLowerCase(),
              isNot(contains(british)),
              reason: '"${block.heading}" uses $british',
            );
          }
        }
      }
    });

    test('How It Helps is the renamed heading', () {
      expect(
        kAboutUsDocument.blocks.map((b) => b.heading),
        contains('How It Helps'),
      );
      expect(
        kAboutUsDocument.blocks.map((b) => b.heading),
        isNot(contains('How it helps')),
      );
      expect(blockNamed(kAboutUsDocument, 'How It Helps').body, contains('organized'));
    });

    test('Data We Collect names the account details it means', () {
      final body = blockNamed(kPrivacyPolicyDocument, 'Data We Collect').body;

      expect(body, contains('name and email'));
      expect(body, contains("app's features"));
    });

    test('AI Processing is definite, not hedged', () {
      final body = blockNamed(kPrivacyPolicyDocument, 'AI Processing').body;

      // "are processed", not the handoff's "may be processed" — materials
      // always go through the Worker to be turned into questions.
      expect(body, contains('are processed'));
      expect(body, isNot(contains('may be processed')));
    });

    test('Your Rights points at what the app can actually do', () {
      final body = blockNamed(kPrivacyPolicyDocument, 'Your Rights').body;

      // There is no in-app account deletion and no in-app email change, so
      // the copy names Edit Profile and an email address instead of
      // promising "update your account information or delete your account".
      expect(body, contains('Edit Profile'));
      expect(body, contains('tadarabapp@gmail.com'));
      expect(body, isNot(contains('delete your account at any time')));
    });

    test('Privacy Commitment and Data Security are unchanged', () {
      expect(
        blockNamed(kPrivacyPolicyDocument, 'Privacy Commitment').body,
        'Tadarab respects your privacy and is committed to protecting your '
            'personal information.',
      );
      expect(
        blockNamed(kPrivacyPolicyDocument, 'Data Security').body,
        'We do not sell your personal information, and we take reasonable '
            'measures to keep your data secure.',
      );
    });

    test('Generated Content keeps the warning but drops "Always"', () {
      final body = blockNamed(kTermsOfUseDocument, 'Generated Content').body;

      expect(body, contains('may contain mistakes'));
      expect(body, startsWith('Quizzes and flashcards are generated'));
      expect(body, isNot(contains('Always check')));
    });

    test('the other Terms blocks are untouched', () {
      expect(
        kTermsOfUseDocument.blocks.map((b) => b.heading),
        ['Using Tadarab', 'Your Content', 'Generated Content', 'Account',
          'Changes'],
      );
    });
  });

  group('Learning Guide (lively variant)', () {
    Future<void> pumpGuide(WidgetTester tester, {int? points}) async {
      tester.view.physicalSize = const Size(412, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(home: LearningGuideScreen(points: points)),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows both points tiles with the real award values', (
      tester,
    ) async {
      await pumpGuide(tester);

      expect(find.text(kGuideEarnHeading), findsOneWidget);
      expect(find.text('+4'), findsOneWidget);
      expect(find.text('+2'), findsOneWidget);
      expect(find.text('Quiz'), findsOneWidget);
      expect(find.text('Flashcards'), findsOneWidget);
      expect(find.text('per correct answer'), findsOneWidget);
      expect(find.text('per card marked Known'), findsOneWidget);
    });

    testWidgets('shows the rank ladder with all ten rungs', (tester) async {
      await pumpGuide(tester);

      expect(find.text(kGuideRankHeading), findsOneWidget);
      expect(find.text(kGuideRankBody), findsOneWidget);
      for (final rank in kRanks) {
        expect(
          find.byKey(ValueKey('guide-rung-${rank.tier}')),
          findsOneWidget,
        );
      }
    });

    test('Retake describes the stack, not a replacement', () {
      final retake = kGuideItems.firstWhere((i) => i.heading == 'Retake');

      // QuizSessionService.retakeSession creates a new session and never
      // touches the source, and each retake increments totalPoints on its
      // own — so the guide must not claim results are replaced.
      expect(retake.body, contains('Your original session is kept'));
      expect(retake.body, contains('as a stack'));
      expect(retake.body, contains('earns its own points'));
      expect(retake.body, contains('new questions or cards'));
      expect(retake.body, isNot(contains('Replaces your old results')));
    });

    test('the points tiles match the values the code actually awards', () {
      // Guards the guide against drifting from pointsPerCorrectAnswer and
      // kPointsPerKnownFlashcard.
      final quiz = kGuidePointsTiles.firstWhere((t) => t.label == 'Quiz');
      final cards = kGuidePointsTiles.firstWhere(
        (t) => t.label == 'Flashcards',
      );

      expect(quiz.points, '+$pointsPerCorrectAnswer');
      expect(quiz.unit, 'per correct answer');
      expect(cards.points, '+$kPointsPerKnownFlashcard');
      expect(cards.unit, 'per card marked Known');
    });

    test('Practice Now and Review Mistakes name the right modes', () {
      // Review mistakes is gated to Mode.exam and Practice Now to
      // Mode.learning in PerformanceSummaryScreen.
      expect(
        kGuideItems.firstWhere((i) => i.heading == 'Practice Now').scope,
        'LEARNING MODE',
      );
      expect(
        kGuideItems.firstWhere((i) => i.heading == 'Review Mistakes').scope,
        'EXAM MODE',
      );
    });

    testWidgets('shows all five explainer cards with their scopes', (
      tester,
    ) async {
      await pumpGuide(tester);

      for (final item in kGuideItems) {
        expect(find.text(item.heading), findsOneWidget, reason: item.heading);
        if (item.scope != null) {
          expect(find.text(item.scope!), findsOneWidget);
        }
      }
    });

    testWidgets('renders without points, and without exception', (
      tester,
    ) async {
      await pumpGuide(tester);

      expect(tester.takeException(), isNull);
    });

    testWidgets('renders at a narrow 320dp width', (tester) async {
      tester.view.physicalSize = const Size(320, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MaterialApp(home: LearningGuideScreen(points: 1450)),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
