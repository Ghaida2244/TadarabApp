import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/theme/app_theme.dart';
import 'package:tadarab_app/widgets/app_button.dart';
import 'package:tadarab_app/widgets/color_picker_dialog.dart';

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
  Future<void> pumpDialog(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showColorPicker(
                context: context,
                initial: AppColors.red,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('"Cancel" looks exactly like the enabled Previous button', (
    tester,
  ) async {
    await pumpDialog(tester);

    final cancelButton = tester.widget<AppButton>(
      find.widgetWithText(AppButton, 'Cancel'),
    );
    expect(cancelButton.variant, AppButtonVariant.outlinedNeutral);
    expect(cancelButton.onPressed, isNotNull);

    expect(_borderColorOf(tester, 'Cancel'), AppColors.navy.withValues(alpha: 0.32));
    expect(_textColorOf(tester, 'Cancel'), AppColors.navy);

    final shadow = _shadowOf(tester, 'Cancel');
    expect(shadow, isNotNull);
    expect(shadow!.single.color, AppColors.navy.withValues(alpha: 0.10));
  });

  testWidgets('tapping "Cancel" closes the dialog with a null result', (
    tester,
  ) async {
    // The dialog's content (saturation area + hue slider + hex field +
    // both buttons) is taller than the default 800x600 test surface, which
    // pushes "Cancel" below the visible viewport and makes it unhittable.
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    Color? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showColorPicker(
                  context: context,
                  initial: AppColors.red,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.byType(ColorPickerDialog), findsNothing);
    expect(result, isNull);
  });
}
