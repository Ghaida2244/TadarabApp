import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/screens/calendar/widgets/calendar_pickers.dart';
import 'package:tadarab_app/theme/app_theme.dart';

void main() {
  final now = DateTime(2026, 5, 3, 9, 0);

  /// Opens one of the pickers from a real button, so the theme is resolved
  /// exactly as it is in the app rather than read off a ThemeData object.
  Future<void> openPicker(
    WidgetTester tester, {
    required Future<void> Function(BuildContext context) open,
  }) async {
    await tester.binding.setSurfaceSize(const Size(600, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        // The app's own font default, so a test can tell the difference
        // between "inherited Nunito" and "the picker theme set Nunito".
        theme: ThemeData(fontFamily: 'Nunito'),
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => open(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> openDate(WidgetTester tester) => openPicker(
    tester,
    open: (context) async {
      await pickEventDate(
        context: context,
        initialDate: DateTime(2026, 5, 14),
        now: now,
      );
    },
  );

  Future<void> openTime(WidgetTester tester) => openPicker(
    tester,
    open: (context) async {
      await pickEventTime(
        context: context,
        initialTime: const TimeOfDay(hour: 9, minute: 0),
      );
    },
  );

  /// The theme the picker subtree actually resolves.
  DatePickerThemeData dateTheme(WidgetTester tester) =>
      DatePickerTheme.of(tester.element(find.byType(DatePickerDialog)));

  /// The colour of the surface the dialog actually paints — the thing that
  /// read as lavender on the emulator. Asserting the ThemeData alone would
  /// not catch a slot the dialog takes from somewhere else.
  Color? renderedSurface(WidgetTester tester, Type dialogType) {
    final material = tester.widgetList<Material>(
      find.descendant(
        of: find.byType(dialogType),
        matching: find.byType(Material),
      ),
    );
    return material.first.color;
  }

  TimePickerThemeData timeTheme(WidgetTester tester) =>
      TimePickerTheme.of(tester.element(find.byType(TimePickerDialog)));

  group('date picker', () {
    testWidgets('opens on a white surface, not the M3 lavender', (
      tester,
    ) async {
      await openDate(tester);

      final theme = dateTheme(tester);
      expect(theme.backgroundColor, Colors.white);
      expect(theme.headerBackgroundColor, Colors.white);
      // M3 tints the surface by elevation unless this is cleared.
      expect(theme.surfaceTintColor, Colors.transparent);
    });

    testWidgets('paints a white surface, not lavender', (tester) async {
      await openDate(tester);

      expect(renderedSurface(tester, DatePickerDialog), Colors.white);
    });

    testWidgets('uses the design\'s rounded corners', (tester) async {
      await openDate(tester);

      final shape = dateTheme(tester).shape! as RoundedRectangleBorder;
      expect(
        shape.borderRadius,
        BorderRadius.circular(kPickerCornerRadius),
      );
    });

    testWidgets('sets Nunito on every text slot it owns', (tester) async {
      await openDate(tester);

      final theme = dateTheme(tester);
      for (final style in [
        theme.headerHeadlineStyle,
        theme.headerHelpStyle,
        theme.weekdayStyle,
        theme.dayStyle,
        theme.yearStyle,
      ]) {
        expect(style?.fontFamily, 'Nunito');
      }
    });

    testWidgets('selects the day in navy with white ink', (tester) async {
      await openDate(tester);

      final theme = dateTheme(tester);
      expect(
        theme.dayBackgroundColor?.resolve({WidgetState.selected}),
        AppColors.navy,
      );
      expect(
        theme.dayForegroundColor?.resolve({WidgetState.selected}),
        Colors.white,
      );
      // An unselected day stays navy-on-white.
      expect(theme.dayBackgroundColor?.resolve({}), Colors.transparent);
      expect(theme.dayForegroundColor?.resolve({}), AppColors.navy);
    });

    testWidgets('outlines today in red, like the month grid', (tester) async {
      await openDate(tester);

      final theme = dateTheme(tester);
      expect(theme.todayBorder?.color, AppColors.red);
      expect(theme.todayForegroundColor?.resolve({}), AppColors.red);
      // Unless today is also the selection, which wins.
      expect(
        theme.todayForegroundColor?.resolve({WidgetState.selected}),
        Colors.white,
      );
    });

    testWidgets('styles Cancel muted and OK red', (tester) async {
      await openDate(tester);

      final theme = dateTheme(tester);
      expect(
        theme.cancelButtonStyle?.foregroundColor?.resolve({}),
        AppColors.textSecondary,
      );
      expect(
        theme.confirmButtonStyle?.foregroundColor?.resolve({}),
        AppColors.red,
      );
      expect(
        theme.confirmButtonStyle?.textStyle?.resolve({})?.fontFamily,
        'Nunito',
      );
    });

    testWidgets('keeps the standard month-grid layout and still picks', (
      tester,
    ) async {
      // The restyle must not have swapped the layout out: the grid is still
      // Android's, and a day is still selectable through it.
      await openDate(tester);

      expect(find.byType(CalendarDatePicker), findsOneWidget);
      expect(find.text('14'), findsOneWidget);

      await tester.tap(find.text('20'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.byType(DatePickerDialog), findsNothing);
    });

    testWidgets('a past date is still selectable', (tester) async {
      await openDate(tester);

      // The 1st is before "today" (the 3rd) and must not be disabled.
      await tester.tap(find.text('1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.byType(DatePickerDialog), findsNothing);
    });
  });

  group('time picker', () {
    testWidgets('opens on a white surface with the design\'s corners', (
      tester,
    ) async {
      await openTime(tester);

      final theme = timeTheme(tester);
      expect(theme.backgroundColor, Colors.white);
      final shape = theme.shape! as RoundedRectangleBorder;
      expect(
        shape.borderRadius,
        BorderRadius.circular(kPickerCornerRadius),
      );
    });

    testWidgets('paints a white surface, not lavender', (tester) async {
      await openTime(tester);

      expect(renderedSurface(tester, TimePickerDialog), Colors.white);
    });

    testWidgets('sets Nunito on every text slot it owns', (tester) async {
      await openTime(tester);

      final theme = timeTheme(tester);
      for (final style in [
        theme.helpTextStyle,
        theme.hourMinuteTextStyle,
        theme.dayPeriodTextStyle,
        theme.dialTextStyle,
      ]) {
        expect(style?.fontFamily, 'Nunito');
      }
    });

    testWidgets('the selected hour field is navy with white ink', (
      tester,
    ) async {
      await openTime(tester);

      final theme = timeTheme(tester);
      expect(
        WidgetStateProperty.resolveAs<Color?>(
          theme.hourMinuteColor,
          {WidgetState.selected},
        ),
        AppColors.navy,
      );
      expect(
        WidgetStateProperty.resolveAs<Color?>(
          theme.hourMinuteTextColor,
          {WidgetState.selected},
        ),
        Colors.white,
      );
    });

    testWidgets('the dial hand is navy on a muted face', (tester) async {
      await openTime(tester);

      final theme = timeTheme(tester);
      expect(theme.dialHandColor, AppColors.navy);
      expect(theme.dialBackgroundColor, AppColors.surfaceMuted);
    });

    testWidgets('styles Cancel muted and OK red', (tester) async {
      await openTime(tester);

      final theme = timeTheme(tester);
      expect(
        theme.cancelButtonStyle?.foregroundColor?.resolve({}),
        AppColors.textSecondary,
      );
      expect(
        theme.confirmButtonStyle?.foregroundColor?.resolve({}),
        AppColors.red,
      );
    });

    testWidgets('keeps the standard clock dial and still picks', (
      tester,
    ) async {
      await openTime(tester);

      // The dial, not a custom grid.
      expect(find.byType(TimePickerDialog), findsOneWidget);
      expect(find.text('AM'), findsOneWidget);
      expect(find.text('PM'), findsOneWidget);

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.byType(TimePickerDialog), findsNothing);
    });
  });

  group('time picker — initial value', () {
    testWidgets(
      'opens on the injected current time when there is no initialTime',
      (tester) async {
        TimeOfDay? result;
        await openPicker(
          tester,
          open: (context) async {
            result = await pickEventTime(
              context: context,
              initialTime: null,
              now: DateTime(2026, 5, 3, 14, 37),
            );
          },
        );

        // Accepting the dial's own pre-selected value without changing it
        // reveals what it opened on.
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();

        expect(result, const TimeOfDay(hour: 14, minute: 37));
      },
    );

    testWidgets(
      'opens on initialTime when one is set, ignoring a different now — '
      'this is what lets Add Event/Study Reminder reopen on an '
      'already-picked or already-saved time instead of the current one',
      (tester) async {
        TimeOfDay? result;
        await openPicker(
          tester,
          open: (context) async {
            result = await pickEventTime(
              context: context,
              initialTime: const TimeOfDay(hour: 6, minute: 15),
              now: DateTime(2026, 5, 3, 14, 37),
            );
          },
        );

        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();

        expect(result, const TimeOfDay(hour: 6, minute: 15));
      },
    );

  });
}
