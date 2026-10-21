import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/models/enums.dart';
import 'package:tadarab_app/screens/calendar/widgets/reminder_card.dart';
import 'package:tadarab_app/theme/app_theme.dart';

void main() {
  final now = DateTime(2026, 5, 3, 9, 0);

  /// Pumps a card whose state the test drives directly, so each state in the
  /// design can be asserted without going through the whole Add Event form.
  Future<_Recorder> pumpCard(
    WidgetTester tester, {
    bool enabled = true,
    int amount = 1,
    ReminderUnit unit = ReminderUnit.days,
    bool unitsOpen = false,
    DateTime? date,
    TimeOfDay? time,
  }) async {
    final recorder = _Recorder();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ReminderCard(
              enabled: enabled,
              amount: amount,
              unit: unit,
              unitsOpen: unitsOpen,
              date: date,
              time: time,
              now: now,
              onToggled: (v) => recorder.toggled = v,
              onAmountChanged: (v) => recorder.amount = v,
              onUnitChanged: (v) => recorder.unit = v,
              onToggleUnits: () => recorder.unitsToggled++,
              onRejected: (m) => recorder.rejections.add(m),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return recorder;
  }

  group('collapsed', () {
    testWidgets('shows only the toggle row while disabled', (tester) async {
      await pumpCard(tester, enabled: false);

      expect(find.text('Enable reminder'), findsOneWidget);
      expect(find.byKey(const ValueKey('reminder-amount')), findsNothing);
      expect(find.byKey(const ValueKey('reminder-note')), findsNothing);
    });

    testWidgets('tapping the row reports the new value', (tester) async {
      final recorder = await pumpCard(tester, enabled: false);

      await tester.tap(find.byKey(const ValueKey('reminder-toggle')));
      await tester.pumpAndSettle();

      expect(recorder.toggled, isTrue);
    });
  });

  group('note box states', () {
    testWidgets('grey while no date or time is set', (tester) async {
      await pumpCard(tester);

      expect(
        find.text(
          'Pick a date and time and we will check this reminder against them.',
        ),
        findsOneWidget,
      );
      final box = tester.widget<Container>(
        find.byKey(const ValueKey('reminder-note')),
      );
      expect(
        (box.decoration! as BoxDecoration).color,
        AppColors.surfaceMuted,
      );
    });

    testWidgets('green once the lead time lands in the future', (
      tester,
    ) async {
      await pumpCard(
        tester,
        date: DateTime(2026, 5, 14),
        time: const TimeOfDay(hour: 9, minute: 0),
      );

      expect(
        find.text('You will be notified 1 day before this event.'),
        findsOneWidget,
      );
      final box = tester.widget<Container>(
        find.byKey(const ValueKey('reminder-note')),
      );
      expect(
        (box.decoration! as BoxDecoration).color,
        AppColors.successBackgroundStrong,
      );
    });

    testWidgets('red once the lead time has passed', (tester) async {
      await pumpCard(
        tester,
        date: DateTime(2026, 5, 3),
        time: const TimeOfDay(hour: 9, minute: 0),
      );

      expect(
        find.text('1 day before this event has already passed.'),
        findsOneWidget,
      );
      final box = tester.widget<Container>(
        find.byKey(const ValueKey('reminder-note')),
      );
      expect(
        (box.decoration! as BoxDecoration).color,
        AppColors.errorBannerBackground,
      );
    });
  });

  group('stepper bounds', () {
    testWidgets('the minus button is inert at the minimum', (tester) async {
      final recorder = await pumpCard(tester, amount: kReminderAmountMin);

      await tester.tap(find.byKey(const ValueKey('reminder-decrement')));
      await tester.pumpAndSettle();

      expect(recorder.amount, isNull);
    });

    testWidgets('the plus button is inert at the maximum', (tester) async {
      final recorder = await pumpCard(tester, amount: kReminderAmountMax);

      await tester.tap(find.byKey(const ValueKey('reminder-increment')));
      await tester.pumpAndSettle();

      expect(recorder.amount, isNull);
    });

    testWidgets('a disabled stepper button is greyed', (tester) async {
      await pumpCard(tester, amount: kReminderAmountMin);

      final button = tester.widget<Container>(
        find
            .descendant(
              of: find.byKey(const ValueKey('reminder-decrement')),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(
        (button.decoration! as BoxDecoration).color,
        AppColors.cardTint,
      );
    });

    testWidgets('stepping to a passed lead time is rejected, not applied', (
      tester,
    ) async {
      final recorder = await pumpCard(
        tester,
        amount: 1,
        unit: ReminderUnit.days,
        // Two days out, so 1 day before is fine but 2 days before is not.
        date: DateTime(2026, 5, 5),
        time: const TimeOfDay(hour: 9, minute: 0),
      );

      await tester.tap(find.byKey(const ValueKey('reminder-increment')));
      await tester.pumpAndSettle();

      expect(recorder.amount, isNull);
      expect(
        recorder.rejections,
        ['2 days before this event has already passed.'],
      );
    });
  });

  group('unit chips', () {
    testWidgets('are hidden until the unit button is expanded', (
      tester,
    ) async {
      await pumpCard(tester);

      expect(
        find.byKey(const ValueKey('reminder-unit-chip-Day')),
        findsNothing,
      );
    });

    testWidgets('list all four units when open', (tester) async {
      await pumpCard(tester, unitsOpen: true);

      for (final label in ['Minute', 'Hour', 'Day', 'Week']) {
        expect(
          find.byKey(ValueKey('reminder-unit-chip-$label')),
          findsOneWidget,
        );
      }
    });

    testWidgets('a reachable unit is applied on tap', (tester) async {
      final recorder = await pumpCard(
        tester,
        unitsOpen: true,
        date: DateTime(2026, 5, 14),
        time: const TimeOfDay(hour: 9, minute: 0),
      );

      await tester.tap(find.byKey(const ValueKey('reminder-unit-chip-Hour')));
      await tester.pumpAndSettle();

      expect(recorder.unit, ReminderUnit.hours);
      expect(recorder.rejections, isEmpty);
    });

    testWidgets('a passed unit is greyed and ignores the tap', (tester) async {
      final recorder = await pumpCard(
        tester,
        unitsOpen: true,
        // Two days out: Week is unreachable, Day is not.
        date: DateTime(2026, 5, 5),
        time: const TimeOfDay(hour: 9, minute: 0),
      );

      final chip = tester.widget<Container>(
        find
            .descendant(
              of: find.byKey(const ValueKey('reminder-unit-chip-Week')),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(
        (chip.decoration! as BoxDecoration).color,
        AppColors.surfaceMuted,
      );

      await tester.tap(find.byKey(const ValueKey('reminder-unit-chip-Week')));
      await tester.pumpAndSettle();

      expect(recorder.unit, isNull);
      // Blocked chips are inert: no rejection message either, because the
      // tap never reaches the handler.
      expect(recorder.rejections, isEmpty);
    });
  });
}

/// Captures what the card reported back.
class _Recorder {
  bool? toggled;
  int? amount;
  ReminderUnit? unit;
  int unitsToggled = 0;
  final List<String> rejections = [];
}
