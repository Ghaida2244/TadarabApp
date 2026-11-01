import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/screens/profile/about_document_screen.dart';
import 'package:tadarab_app/screens/profile/content/about_content.dart';
import 'package:tadarab_app/screens/profile/learning_guide_screen.dart';
import 'package:tadarab_app/screens/profile/content/learning_guide_content.dart';
import 'package:tadarab_app/features/flashcards/logic/flashcard_logic.dart';
import 'package:tadarab_app/services/quiz_session_service.dart';
import 'package:tadarab_app/theme/app_theme.dart';
import 'package:tadarab_app/utils/rank.dart';
import 'package:tadarab_app/widgets/screen_header.dart';

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

  // Measured by pumping a lone, title-only (no subtitle) ScreenHeader at
  // the same title — the fair comparison for these screens, none of which
  // have a subtitle: padding, title style, button size and border radius
  // are the exact same ScreenHeader component either way, so using each
  // screen's own title (rather than always 'Add course') is what makes
  // this an apples-to-apples check. 'Privacy Policy' and 'Learning
  // Guide' no longer wrap to two lines at a phone width — ScreenHeader's
  // title now shrinks (FittedBox + scaleDown) rather than wrapping — but
  // this still isn't hardcoded to 'Add course' specifically, since that
  // would stop being a fair comparison the moment any title needs even a
  // little of that shrink.
  Future<double> referenceScreenHeaderHeight(
    WidgetTester tester,
    String title,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              ScreenHeader(
                title: title,
                backgroundColor: AppColors.navy,
                onClose: () {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    return tester.getSize(find.byType(ScreenHeader)).height;
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

    testWidgets('the back chevron sits to the left of the title', (
      tester,
    ) async {
      await pumpDocument(tester, kAboutUsDocument);

      final screenHeader = tester.widget<ScreenHeader>(
        find.byType(ScreenHeader),
      );
      expect(screenHeader.buttonOnStart, isTrue);

      final buttonX = tester.getTopLeft(find.byIcon(Icons.chevron_left)).dx;
      final titleX = tester.getTopLeft(find.text('About Us')).dx;
      expect(buttonX, lessThan(titleX));
    });

    testWidgets('tapping the back chevron pops', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        AboutDocumentScreen(document: kAboutUsDocument),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(AboutDocumentScreen), findsOneWidget);

      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();

      expect(find.byType(AboutDocumentScreen), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });

    for (final document in [
      kAboutUsDocument,
      kPrivacyPolicyDocument,
      kTermsOfUseDocument,
    ]) {
      testWidgets(
        '${document.title}\'s header is the shared ScreenHeader, the '
        "same height as Add course's own (title-only, no subtitle)",
        (tester) async {
          await pumpDocument(tester, document);

          final headerFinder = find.byType(ScreenHeader);
          expect(headerFinder, findsOneWidget);
          final realHeight = tester.getSize(headerFinder).height;

          final referenceHeight = await referenceScreenHeaderHeight(
            tester,
            document.title,
          );

          expect(realHeight, referenceHeight);
        },
      );
    }
  });

  group('Privacy Policy title stays on one line', () {
    // 14 characters at the header's 26px/w900 title style needs ~357
    // logical pixels unscaled — more than a 360 or 412dp phone's header
    // has left over once its own padding and the back button are
    // subtracted. ScreenHeader's title now shrinks as a whole (FittedBox
    // + scaleDown) instead of wrapping to a second line, so this checks
    // it never wraps at either width, not that it stays at full size.
    for (final width in [360.0, 412.0]) {
      testWidgets('never wraps at ${width.toInt()}dp width', (tester) async {
        tester.view.physicalSize = Size(width, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MaterialApp(
            home: AboutDocumentScreen(document: kPrivacyPolicyDocument),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);

        // Measuring the FittedBox itself, not the Text inside it: a
        // FittedBox's child is always laid out at its own natural,
        // unconstrained size first (which is why measuring the Text
        // directly would read ~37px regardless of how much it then gets
        // scaled down) — the FittedBox's own rendered size is what
        // reflects the real, visible, scaled result. A single line
        // scales down to under 40px at both widths (27.9px at 360dp,
        // 33.3px at 412dp, measured directly); two wrapped lines would
        // still be at least ~60px even after scaling, since scaling
        // preserves the (now much squarer) aspect ratio wrapping would
        // produce.
        final fittedBoxHeight = tester
            .getSize(find.byType(FittedBox))
            .height;
        expect(fittedBoxHeight, lessThan(40));
      });
    }
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
      // No em dash — the design handoff's copy style avoids it.
      expect(retake.body, isNot(contains('—')));
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

    testWidgets(
      'the header is the shared ScreenHeader, the same height as Add '
      "course's own (title-only, no subtitle)",
      (tester) async {
        await pumpGuide(tester);

        final headerFinder = find.byType(ScreenHeader);
        expect(headerFinder, findsOneWidget);
        final realHeight = tester.getSize(headerFinder).height;

        final referenceHeight = await referenceScreenHeaderHeight(
          tester,
          'Learning Guide',
        );

        expect(realHeight, referenceHeight);
      },
    );

    testWidgets('the back chevron sits to the left of the title', (
      tester,
    ) async {
      await pumpGuide(tester);

      final screenHeader = tester.widget<ScreenHeader>(
        find.byType(ScreenHeader),
      );
      expect(screenHeader.buttonOnStart, isTrue);

      final buttonX = tester.getTopLeft(find.byIcon(Icons.chevron_left)).dx;
      final titleX = tester.getTopLeft(find.text('Learning Guide')).dx;
      expect(buttonX, lessThan(titleX));
    });

    testWidgets('tapping the back chevron pops', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const LearningGuideScreen(points: 1450),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(LearningGuideScreen), findsOneWidget);

      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();

      expect(find.byType(LearningGuideScreen), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });

    for (final width in [360.0, 412.0]) {
      testWidgets(
        'the title never wraps at ${width.toInt()}dp width',
        (tester) async {
          tester.view.physicalSize = Size(width, 2400);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(
            const MaterialApp(home: LearningGuideScreen(points: 1450)),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);

          // See the equivalent 'Privacy Policy' check above for why the
          // FittedBox itself, not the Text inside it, is what has to be
          // measured.
          final fittedBoxHeight = tester
              .getSize(find.byType(FittedBox))
              .height;
          expect(fittedBoxHeight, lessThan(40));
        },
      );
    }
  });
}
