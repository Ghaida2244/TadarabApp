import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/features/flashcards/widgets/save_and_leave_sheet.dart';

void main() {
  testWidgets('shows the reviewed count and the resume card number', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showSaveAndLeaveSheet(
                context,
                reviewedCount: 4,
                total: 10,
                resumeCardNumber: 5,
                onSaveAndLeave: () {},
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Leave this deck?'), findsOneWidget);
    expect(
      find.text(
        'You have marked 4 of 10 cards. We will keep this session so you '
        'can pick it up at card 5.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Save and leave invokes the callback and closes the sheet', (
    tester,
  ) async {
    var saved = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showSaveAndLeaveSheet(
                context,
                reviewedCount: 1,
                total: 5,
                resumeCardNumber: 2,
                onSaveAndLeave: () => saved = true,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save and leave'));
    await tester.pumpAndSettle();

    expect(saved, isTrue);
    expect(find.text('Leave this deck?'), findsNothing);
  });

  testWidgets('Keep going dismisses without invoking the callback', (
    tester,
  ) async {
    var saved = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showSaveAndLeaveSheet(
                context,
                reviewedCount: 1,
                total: 5,
                resumeCardNumber: 2,
                onSaveAndLeave: () => saved = true,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep going'));
    await tester.pumpAndSettle();

    expect(saved, isFalse);
    expect(find.text('Leave this deck?'), findsNothing);
  });
}
