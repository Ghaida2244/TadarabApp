import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/models/question.dart';
import 'package:tadarab_app/screens/quiz/review_mistakes_screen.dart';

List<Question> _mistakes({String? blankFor}) {
  return [
    Question(
      questionId: 'q1',
      questionText: 'What is a database?',
      correctAnswer: 'A collection of related data',
      explanation: 'It organizes related data for access and management.',
      sourceLocation: 'Slide 1',
      studentAnswer: blankFor == 'q1' ? null : 'A programming language',
      options: const [
        'A collection of unrelated data',
        'A collection of related data',
        'A programming language',
        'A hardware device',
      ],
      sessionId: 's1',
    ),
  ];
}

void main() {
  testWidgets('normal case: header count, question, and the wrong pick are shown collapsed', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ReviewMistakesScreen(mistakes: _mistakes(), totalQuestions: 10),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 wrong out of 10'), findsOneWidget);
    expect(find.text('What is a database?'), findsOneWidget);
    expect(find.text('You chose: A programming language'), findsOneWidget);
    expect(find.text('Correct: A collection of related data'), findsNothing);
    expect(find.text('EXPLANATION'), findsNothing);
    expect(find.text('Show the answer'), findsOneWidget);
  });

  testWidgets('edge case: a left-blank question says so instead of "You chose"', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ReviewMistakesScreen(
          mistakes: _mistakes(blankFor: 'q1'),
          totalQuestions: 10,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('You left this one blank'), findsOneWidget);
  });

  testWidgets('expanding shows the correct answer and explanation, and flips the toggle label', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ReviewMistakesScreen(mistakes: _mistakes(), totalQuestions: 10),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Show the answer'));
    await tester.pumpAndSettle();

    expect(find.text('Correct: A collection of related data'), findsOneWidget);
    expect(find.text('EXPLANATION'), findsOneWidget);
    expect(find.text('Hide details'), findsOneWidget);

    await tester.tap(find.text('Hide details'));
    await tester.pumpAndSettle();

    expect(find.text('Correct: A collection of related data'), findsNothing);
    expect(find.text('Show the answer'), findsOneWidget);
  });

  testWidgets('the plural count reads "N wrong out of" for more than one mistake', (tester) async {
    final twoMistakes = [
      ..._mistakes(),
      Question(
        questionId: 'q2',
        questionText: 'Q2',
        correctAnswer: 'Right',
        explanation: 'E',
        sourceLocation: 'Slide 2',
        studentAnswer: 'Wrong',
        options: const ['Right', 'Wrong'],
        sessionId: 's1',
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(home: ReviewMistakesScreen(mistakes: twoMistakes, totalQuestions: 10)),
    );
    await tester.pumpAndSettle();

    expect(find.text('2 wrong out of 10'), findsOneWidget);
  });

  testWidgets(
    'has no "Back to course" button — the back arrow is the only way out, and it goes to Summary, not past it',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          onGenerateRoute: (_) => MaterialPageRoute(
            builder: (_) => const Scaffold(body: Text('Summary placeholder')),
          ),
        ),
      );
      final navigatorState = tester.state<NavigatorState>(find.byType(Navigator));
      unawaited(
        navigatorState.push(
          MaterialPageRoute(
            builder: (_) => ReviewMistakesScreen(mistakes: _mistakes(), totalQuestions: 10),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Back to course'), findsNothing);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text('Summary placeholder'), findsOneWidget);
    },
  );
}
