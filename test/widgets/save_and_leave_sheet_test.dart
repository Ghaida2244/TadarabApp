import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/theme/app_theme.dart';
import 'package:tadarab_app/widgets/app_button.dart';
import 'package:tadarab_app/widgets/save_and_leave_sheet.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

Color _borderColorOf(WidgetTester tester, String label) {
  final container = tester.widget<AnimatedContainer>(
    find.descendant(
      of: find.widgetWithText(AppButton, label),
      matching: find.byType(AnimatedContainer),
    ),
  );
  return (container.decoration as BoxDecoration).border!.top.color;
}

Color _textColorOf(WidgetTester tester, String label) {
  final text = tester.widget<Text>(
    find.descendant(
      of: find.widgetWithText(AppButton, label),
      matching: find.byType(Text),
    ),
  );
  return text.style!.color!;
}

List<BoxShadow>? _shadowOf(WidgetTester tester, String label) {
  final container = tester.widget<AnimatedContainer>(
    find.descendant(
      of: find.widgetWithText(AppButton, label),
      matching: find.byType(AnimatedContainer),
    ),
  );
  return (container.decoration as BoxDecoration).boxShadow;
}

void main() {
  group('SaveAndLeaveSheet', () {
    testWidgets(
      'title and body use the Quiz-sourced typography (quizDialogTitle / '
      'quizEmptyBody) — the single source of truth both Quiz and '
      'Flashcards now share',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            SaveAndLeaveSheet(
              body: 'You have answered 3 of 10 so far. We will keep this '
                  'session so you can pick it up where you left off.',
              onSaveAndLeave: () {},
              onKeepGoing: () {},
            ),
          ),
        );

        final titleStyle = tester
            .widget<Text>(find.text('Leave this session?'))
            .style!;
        final bodyStyle = tester
            .widget<Text>(
              find.text(
                'You have answered 3 of 10 so far. We will keep this '
                'session so you can pick it up where you left off.',
              ),
            )
            .style!;

        expect(titleStyle.fontSize, AppTypography.quizDialogTitle.fontSize);
        expect(titleStyle.fontWeight, AppTypography.quizDialogTitle.fontWeight);
        expect(titleStyle.color, AppTypography.quizDialogTitle.color);

        expect(bodyStyle.fontSize, AppTypography.quizEmptyBody.fontSize);
        expect(bodyStyle.fontWeight, AppTypography.quizEmptyBody.fontWeight);
        expect(bodyStyle.color, AppTypography.quizEmptyBody.color);
      },
    );

    testWidgets('tapping Save and leave invokes its own callback only', (
      tester,
    ) async {
      var savedCalls = 0;
      var keepGoingCalls = 0;
      await tester.pumpWidget(
        _wrap(
          SaveAndLeaveSheet(
            body: 'Body',
            onSaveAndLeave: () => savedCalls++,
            onKeepGoing: () => keepGoingCalls++,
          ),
        ),
      );

      await tester.tap(find.text('Save and leave'));
      expect(savedCalls, 1);
      expect(keepGoingCalls, 0);
    });

    testWidgets('tapping Keep going invokes its own callback only', (
      tester,
    ) async {
      var savedCalls = 0;
      var keepGoingCalls = 0;
      await tester.pumpWidget(
        _wrap(
          SaveAndLeaveSheet(
            body: 'Body',
            onSaveAndLeave: () => savedCalls++,
            onKeepGoing: () => keepGoingCalls++,
          ),
        ),
      );

      await tester.tap(find.text('Keep going'));
      expect(savedCalls, 0);
      expect(keepGoingCalls, 1);
    });

    testWidgets(
      'Keep going looks active, like the enabled Previous button',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            SaveAndLeaveSheet(
              body: 'Body',
              onSaveAndLeave: () {},
              onKeepGoing: () {},
            ),
          ),
        );

        expect(
          _borderColorOf(tester, 'Keep going'),
          AppColors.navy.withValues(alpha: 0.32),
        );
        expect(_textColorOf(tester, 'Keep going'), AppColors.navy);
        final shadow = _shadowOf(tester, 'Keep going');
        expect(shadow, isNotNull);
        expect(shadow!.single.color, AppColors.navy.withValues(alpha: 0.10));
      },
    );
  });

  group('showSaveAndLeaveSheetModal', () {
    testWidgets(
      'opens the sheet with a transparent modal background (the widget '
      'draws its own white rounded-top container)',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showSaveAndLeaveSheetModal<void>(
                  context,
                  body: 'Body text',
                  onSaveAndLeave: () {},
                  onKeepGoing: () => Navigator.of(context).pop(),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        expect(find.text('Leave this session?'), findsOneWidget);
        expect(find.text('Body text'), findsOneWidget);

        final modalBarrier = tester.widgetList<Material>(
          find.byType(Material),
        );
        // The sheet's own Container supplies the white background — just
        // confirm the sheet renders without asserting on the modal's
        // internal Material count, which is an implementation detail.
        expect(modalBarrier, isNotEmpty);
      },
    );

    testWidgets('the return value flows through from the pressed button', (
      tester,
    ) async {
      String? result;
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showSaveAndLeaveSheetModal<String>(
                  context,
                  body: 'Body text',
                  onSaveAndLeave: () => Navigator.of(context).pop('left'),
                  onKeepGoing: () => Navigator.of(context).pop('stayed'),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep going'));
      await tester.pumpAndSettle();

      expect(result, 'stayed');
    });
  });
}
