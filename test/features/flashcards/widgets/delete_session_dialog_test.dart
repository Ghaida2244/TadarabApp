import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/features/flashcards/widgets/delete_session_dialog.dart';

void main() {
  testWidgets('completed variant shows the counts-and-review-list body', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showDeleteSessionDialog(
                context,
                isCompleted: true,
                knownCount: 5,
                needsReviewCount: 2,
                onDelete: () {},
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Delete this session?'), findsOneWidget);
    expect(
      find.text("Its counts and review list will go with it. This can't be undone."),
      findsOneWidget,
    );
  });

  testWidgets('in-progress variant shows the marked-cards-count body', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showDeleteSessionDialog(
                context,
                isCompleted: false,
                knownCount: 3,
                needsReviewCount: 1,
                onDelete: () {},
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(
      find.text("You will lose the 4 cards already marked. This can't be undone."),
      findsOneWidget,
    );
  });

  testWidgets('tapping Delete session invokes onDelete and closes the dialog', (
    tester,
  ) async {
    var deleted = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showDeleteSessionDialog(
                context,
                isCompleted: true,
                knownCount: 1,
                needsReviewCount: 0,
                onDelete: () => deleted = true,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete session'));
    await tester.pumpAndSettle();

    expect(deleted, isTrue);
    expect(find.text('Delete this session?'), findsNothing);
  });

  testWidgets('tapping Keep it dismisses without invoking onDelete', (
    tester,
  ) async {
    var deleted = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showDeleteSessionDialog(
                context,
                isCompleted: true,
                knownCount: 1,
                needsReviewCount: 0,
                onDelete: () => deleted = true,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep it'));
    await tester.pumpAndSettle();

    expect(deleted, isFalse);
    expect(find.text('Delete this session?'), findsNothing);
  });
}
