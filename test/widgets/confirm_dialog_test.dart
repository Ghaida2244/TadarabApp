import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/theme/app_theme.dart';
import 'package:tadarab_app/widgets/app_button.dart';
import 'package:tadarab_app/widgets/confirm_dialog.dart';

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

/// Asserts [label]'s button looks exactly like the enabled Previous button:
/// navy text, navy-at-32%-alpha border, navy-at-10%-alpha shadow.
void _expectActiveSecondaryLook(WidgetTester tester, String label) {
  expect(_borderColorOf(tester, label), AppColors.navy.withValues(alpha: 0.32));
  expect(_textColorOf(tester, label), AppColors.navy);
  final shadow = _shadowOf(tester, label);
  expect(shadow, isNotNull);
  expect(shadow!.single.color, AppColors.navy.withValues(alpha: 0.10));
  expect(shadow.single.offset, const Offset(0, 3));
  expect(shadow.single.blurRadius, 0);
}

Future<bool?> _open(
  WidgetTester tester, {
  String title = 'Delete this session?',
  String message = "This can't be undone.",
  String confirmLabel = 'Delete session',
}) async {
  bool? result;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await showConfirmDialog(
                context,
                title: title,
                message: message,
                confirmLabel: confirmLabel,
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
  return result;
}

void main() {
  testWidgets('shows a centered icon, title, message and both buttons', (
    tester,
  ) async {
    await _open(
      tester,
      title: 'Delete IS463?',
      message: 'This will delete everything.',
      confirmLabel: 'Delete course',
    );

    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    expect(find.text('Delete IS463?'), findsOneWidget);
    expect(find.text('This will delete everything.'), findsOneWidget);
    expect(find.text('Delete course'), findsOneWidget);
    expect(find.text('Keep it'), findsOneWidget);

    final titleWidget = tester.widget<Text>(find.text('Delete IS463?'));
    expect(titleWidget.textAlign, TextAlign.center);
    final messageWidget = tester.widget<Text>(
      find.text('This will delete everything.'),
    );
    expect(messageWidget.textAlign, TextAlign.center);
  });

  testWidgets('tapping the confirm button resolves true', (tester) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showConfirmDialog(
                  context,
                  title: 'Delete this session?',
                  message: "This can't be undone.",
                  confirmLabel: 'Delete session',
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

    await tester.tap(find.text('Delete session'));
    await tester.pumpAndSettle();

    expect(find.text('Delete this session?'), findsNothing);
    expect(result, isTrue);
  });

  testWidgets('tapping "Keep it" resolves false', (tester) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showConfirmDialog(
                  context,
                  title: 'Delete this session?',
                  message: "This can't be undone.",
                  confirmLabel: 'Delete session',
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

    await tester.tap(find.text('Keep it'));
    await tester.pumpAndSettle();

    expect(find.text('Delete this session?'), findsNothing);
    expect(result, isFalse);
  });

  testWidgets('tapping outside the dialog resolves false, same as before', (
    tester,
  ) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showConfirmDialog(
                  context,
                  title: 'Delete this session?',
                  message: "This can't be undone.",
                  confirmLabel: 'Delete session',
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

    // Tap the modal barrier, well outside the dialog's own content.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(find.text('Delete this session?'), findsNothing);
    expect(result, isFalse);
  });

  testWidgets(
    'barrierDismissible: false blocks an outside tap from resolving anything',
    (tester) async {
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await showConfirmDialog(
                    context,
                    title: 'Fewer questions than asked',
                    message: 'Start with these 3, or add another material.',
                    confirmLabel: 'Start with these',
                    barrierDismissible: false,
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

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.text('Fewer questions than asked'), findsOneWidget);
      expect(result, isNull);
    },
  );

  testWidgets('Delete button: red, full-width, with a half-strength red '
      'shadow (no border/text overrides)', (tester) async {
    await _open(tester);

    final deleteButton = tester.widget<AppButton>(
      find.widgetWithText(AppButton, 'Delete session'),
    );
    expect(deleteButton.variant, AppButtonVariant.accent);

    final shadow = _shadowOf(tester, 'Delete session');
    expect(shadow, isNotNull);
    expect(shadow!.single.color, AppColors.redShadow.withValues(alpha: 0.5));
    expect(shadow.single.offset, const Offset(0, 3));
    expect(shadow.single.blurRadius, 0);
  });

  testWidgets('"Keep it" looks exactly like the enabled Previous button', (
    tester,
  ) async {
    await _open(tester);

    final keepIt = tester.widget<AppButton>(
      find.widgetWithText(AppButton, 'Keep it'),
    );
    expect(keepIt.variant, AppButtonVariant.outlinedNeutral);
    expect(keepIt.onPressed, isNotNull);
    _expectActiveSecondaryLook(tester, 'Keep it');
  });

  testWidgets('default icon is the trash icon on a red-on-pink badge', (
    tester,
  ) async {
    await _open(tester);

    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    final container = tester.widget<Container>(
      find.ancestor(
        of: find.byIcon(Icons.delete_outline),
        matching: find.byType(Container),
      ),
    );
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.color, AppColors.errorBannerBackground);
    final icon = tester.widget<Icon>(find.byIcon(Icons.delete_outline));
    expect(icon.color, AppColors.red);
  });

  testWidgets('a custom icon, icon colours and primary variant are honoured', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showConfirmDialog(
                context,
                title: 'Fewer cards than asked',
                message: 'Start with these 3, or add another material.',
                confirmLabel: 'Start with these 3',
                cancelLabel: 'Change the setup',
                icon: Icons.warning_amber_rounded,
                iconColor: AppColors.warningText,
                iconBackgroundColor: AppColors.warningBackground,
                confirmVariant: AppButtonVariant.primary,
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
    final confirmButton = tester.widget<AppButton>(
      find.widgetWithText(AppButton, 'Start with these 3'),
    );
    expect(confirmButton.variant, AppButtonVariant.primary);
    // A non-accent primary button gets no red-shadow fallback — it falls
    // through to AppButtonVariant.primary's own default navy shadow
    // instead, exactly as if no shadowColor had ever been passed.
    final shadow = _shadowOf(tester, 'Start with these 3');
    expect(shadow, isNotNull);
    expect(shadow!.single.color, AppColors.navyShadow);
    _expectActiveSecondaryLook(tester, 'Change the setup');
  });

  testWidgets('renders with no overflow at 320x568 and 1.3x text scale, '
      'with the longest (course) message', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showConfirmDialog(
                  context,
                  title: 'Delete Introduction to Information Systems?',
                  message:
                      'Deleting this course will also delete all its '
                      'materials, quizzes, flashcard sessions, and '
                      "calendar events with their reminders. This can't "
                      'be undone.',
                  confirmLabel: 'Delete course',
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
