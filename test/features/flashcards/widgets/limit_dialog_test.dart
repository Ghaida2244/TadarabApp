import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/features/flashcards/widgets/limit_dialog.dart';
import 'package:tadarab_app/theme/app_theme.dart';
import 'package:tadarab_app/widgets/app_button.dart';

Color _borderColorOf(WidgetTester tester, String label) {
  final container = tester.widget<AnimatedContainer>(
    find.descendant(
      of: find.widgetWithText(AppButton, label),
      matching: find.byType(AnimatedContainer),
    ),
  );
  return (container.decoration as BoxDecoration).border!.top.color;
}

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

  testWidgets('shows the yellow warning icon and a navy primary button', (
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

    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    final container = tester.widget<Container>(
      find.ancestor(
        of: find.byIcon(Icons.warning_amber_rounded),
        matching: find.byType(Container),
      ),
    );
    expect(
      (container.decoration as BoxDecoration).color,
      AppColors.warningBackground,
    );
    final icon = tester.widget<Icon>(
      find.byIcon(Icons.warning_amber_rounded),
    );
    expect(icon.color, AppColors.warningText);

    final confirmButton = tester.widget<AppButton>(
      find.widgetWithText(AppButton, 'Start with these 7'),
    );
    expect(confirmButton.variant, AppButtonVariant.primary);

    expect(
      _borderColorOf(tester, 'Change the setup'),
      AppColors.navy.withValues(alpha: 0.32),
    );
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

  testWidgets(
    'tapping outside the dialog invokes neither callback (not dismissible)',
    (tester) async {
      var started = false;
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
                  onStartWithActual: () => started = true,
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
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.text('Fewer cards than asked'), findsOneWidget);
      expect(started, isFalse);
      expect(changed, isFalse);
    },
  );
}
