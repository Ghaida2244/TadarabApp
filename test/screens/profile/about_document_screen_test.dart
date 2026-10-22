import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/screens/profile/about_document_screen.dart';
import 'package:tadarab_app/screens/profile/content/about_content.dart';
import 'package:tadarab_app/screens/profile/learning_guide_screen.dart';
import 'package:tadarab_app/screens/profile/content/learning_guide_content.dart';
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
