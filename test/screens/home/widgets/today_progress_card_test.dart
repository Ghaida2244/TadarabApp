import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/screens/home/widgets/today_progress_card.dart';
import 'package:tadarab_app/services/home_data_service.dart';
import 'package:tadarab_app/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Widget tests don't load custom fonts from pubspec by default, which
  // would leave the day-cell label measured against Flutter's much taller
  // fallback test font instead of the real, more compact bundled Nunito —
  // an overflow caused purely by that mismatch, not by anything this card
  // actually does on a real device. Loading the real font here makes these
  // layout assertions represent production, not a test-harness artifact.
  setUpAll(() async {
    final fontLoader = FontLoader('Nunito')
      ..addFont(rootBundle.load('assets/fonts/Nunito-VariableFont_wght.ttf'));
    await fontLoader.load();
  });

  // Thursday, so the week includes some past days, today, and some future
  // days — exercises every DayCellFillState the row can show.
  final now = DateTime(2026, 10, 15, 9);
  final weekStart = startOfWeek(now);

  WeeklyProgress weeklyProgress() {
    final days = List.generate(7, (i) {
      final date = DateTime(weekStart.year, weekStart.month, weekStart.day + i);
      // A couple of days (including today) have real activity, so the
      // active/filled cell state — not just the empty one — is exercised
      // too.
      final hasActivity = i == 1 || date == DateTime(now.year, now.month, now.day);
      return DailyStudyCount(
        date: date,
        questionCount: hasActivity ? 12 : 0,
        flashcardCount: hasActivity ? 8 : 0,
      );
    });
    return WeeklyProgress(weekStart: weekStart, days: days);
  }

  // theme: AppTheme.themeData matters here, not just cosmetically: the day
  // label's TextStyle doesn't set its own fontFamily, so it inherits
  // whichever Theme is in scope. Without the real app theme, it would
  // inherit Flutter's default theme's font instead of the bundled Nunito —
  // a wider/taller font that wraps this 4-character label onto two lines
  // at this cell's real width, overflowing the row for reasons that have
  // nothing to do with text *scale* and would not happen in the real app.
  Widget buildCard({required double textScaleFactor}) {
    return MaterialApp(
      theme: AppTheme.themeData,
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScaleFactor)),
        child: Scaffold(
          body: TodayProgressCard(
            weeklyProgress: weeklyProgress(),
            currentStreak: 1,
            lastStudyDate: DateTime(now.year, now.month, now.day),
            now: now,
            fetchWeek: (weekStart) async => WeeklyProgress.empty(weekStart),
          ),
        ),
      ),
    );
  }

  group('overflow safety at larger text scales and narrow screens', () {
    const screenSizes = [Size(360, 640), Size(320, 568)];
    const textScaleFactors = [1.0, 1.3, 1.5, 2.0];

    for (final size in screenSizes) {
      for (final textScaleFactor in textScaleFactors) {
        testWidgets(
          'renders with no overflow at ${size.width.toInt()}x'
          '${size.height.toInt()} and ${textScaleFactor}x text scale',
          (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1.0;
            addTearDown(tester.view.reset);

            await tester.pumpWidget(
              buildCard(textScaleFactor: textScaleFactor),
            );
            await tester.pump();

            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  });

  group('normal text scale is unchanged', () {
    testWidgets('day cell label and week row keep their original size at '
        '1.0x text scale', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(buildCard(textScaleFactor: 1.0));
      await tester.pump();

      expect(tester.takeException(), isNull);

      // The pager's single-row SizedBox: 34 (cell) + 6 (gap) + 14 (label
      // budget) at a scale factor of 1.0 — unchanged from before this fix.
      final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
      expect(
        sizedBoxes.any((box) => box.height == 54.0),
        isTrue,
        reason: 'week row height must stay 54.0 at normal text scale',
      );
    });
  });

  group('content', () {
    testWidgets('shows the streak label and today\'s question/flashcard '
        'counts', (tester) async {
      await tester.pumpWidget(buildCard(textScaleFactor: 1.0));
      await tester.pump();

      expect(find.text('1-day streak'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
      expect(find.text('questions'), findsOneWidget);
      expect(find.text('flashcards'), findsOneWidget);
    });
  });
}
