import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/screens/profile/widgets/logout_dialog.dart';
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
  Future<bool?> showIt(WidgetTester tester) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async => result = await showLogOutDialog(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('shows the badge, the design\'s copy and both actions', (
    tester,
  ) async {
    await showIt(tester);

    expect(find.byIcon(Icons.logout), findsWidgets);
    expect(find.text(kLogOutTitle), findsOneWidget);
    expect(find.text(kLogOutBody), findsOneWidget);
    expect(find.text('Log out'), findsOneWidget);
    expect(find.text('Stay signed in'), findsOneWidget);
  });

  testWidgets('the body text has no dash — it uses two plain sentences', (
    tester,
  ) async {
    await showIt(tester);

    expect(
      kLogOutBody,
      'Your courses, points and sessions stay safe. You will just need to '
      'sign in again.',
    );
    expect(kLogOutBody.contains('—'), isFalse);
    expect(kLogOutBody.contains('–'), isFalse);
  });

  testWidgets('"Stay signed in" looks active, like the enabled Previous button', (
    tester,
  ) async {
    await showIt(tester);

    expect(
      _borderColorOf(tester, 'Stay signed in'),
      AppColors.navy.withValues(alpha: 0.32),
    );
  });

  testWidgets('"Log out" resolves true', (tester) async {
    await showIt(tester);

    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();

    expect(find.text(kLogOutTitle), findsNothing);
  });

  testWidgets('"Stay signed in" resolves false', (tester) async {
    await showIt(tester);

    await tester.tap(find.text('Stay signed in'));
    await tester.pumpAndSettle();

    expect(find.text(kLogOutTitle), findsNothing);
  });

  testWidgets('tapping the scrim dismisses without confirming', (
    tester,
  ) async {
    await showIt(tester);

    // Outside the dialog — a barrier tap must read as "stay signed in".
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(find.text(kLogOutTitle), findsNothing);
  });
}
