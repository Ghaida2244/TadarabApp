import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/features/flashcards/widgets/limit_dialog.dart';

void main() {
  testWidgets('shows the fewer-cards message with actual and requested counts', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showFewerCardsDialog(
                context,
                actualCount: 7,
                requestedCount: 10,
                onStartWithActual: () {},
                onChangeSetup: () {},
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Fewer cards than asked'), findsOneWidget);
    expect(
      find.text(
        'Your material supported 7 solid cards out of the 10 you aimed '
        'for. Start with these 7, or add another material.',
      ),
      findsOneWidget,
    );
    expect(find.text('Start with these 7'), findsOneWidget);
  });

  testWidgets('Start with these N invokes onStartWithActual', (tester) async {
    var started = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showFewerCardsDialog(
                context,
                actualCount: 3,
                requestedCount: 5,
                onStartWithActual: () => started = true,
                onChangeSetup: () {},
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start with these 3'));
    await tester.pumpAndSettle();

    expect(started, isTrue);
  });

  testWidgets('Change the setup invokes onChangeSetup', (tester) async {
    var changed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showFewerCardsDialog(
                context,
                actualCount: 3,
                requestedCount: 5,
                onStartWithActual: () {},
                onChangeSetup: () => changed = true,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change the setup'));
    await tester.pumpAndSettle();

    expect(changed, isTrue);
  });
}
