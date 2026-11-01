import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/screens/profile/ranks_screen.dart';
import 'package:tadarab_app/screens/profile/widgets/rank_icon.dart';
import 'package:tadarab_app/theme/app_theme.dart';
import 'package:tadarab_app/utils/rank.dart';
import 'package:tadarab_app/widgets/screen_header.dart';

void main() {
  Future<void> pumpRanks(WidgetTester tester, int points) async {
    // Tall enough that every one of the ten lazily-built rows exists.
    tester.view.physicalSize = const Size(412, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(home: RanksScreen(points: points)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lists all ten ranks with their ranges and tier numbers', (
    tester,
  ) async {
    await pumpRanks(tester, 0);

    expect(find.text('Ranks'), findsOneWidget);
    for (final rank in kRanks) {
      expect(find.text(rank.name), findsOneWidget, reason: rank.name);
      expect(find.text(rank.rangeLabel), findsOneWidget);
      expect(find.text('${rank.tier} / 10'), findsOneWidget);
      expect(
        find.byKey(ValueKey('rank-icon-${rank.tier}')),
        findsOneWidget,
      );
    }
  });

  testWidgets('a new student has one rank in progress and nine locked', (
    tester,
  ) async {
    await pumpRanks(tester, 0);

    expect(find.text('IN PROGRESS'), findsOneWidget);
    expect(find.text('LOCKED'), findsNWidgets(9));
    expect(find.text('COMPLETED'), findsNothing);
  });

  testWidgets('a mid-ladder student has the right split', (tester) async {
    // 1450 is Skilled Learner, tier 5: four behind, one current, five ahead.
    await pumpRanks(tester, 1450);

    expect(find.text('COMPLETED'), findsNWidgets(4));
    expect(find.text('IN PROGRESS'), findsOneWidget);
    expect(find.text('LOCKED'), findsNWidgets(5));
  });

  testWidgets('the top rank completes the other nine', (tester) async {
    await pumpRanks(tester, 7500);

    expect(find.text('COMPLETED'), findsNWidgets(9));
    expect(find.text('IN PROGRESS'), findsOneWidget);
    expect(find.text('LOCKED'), findsNothing);
  });

  testWidgets('percentages read 100 behind, 0 ahead', (tester) async {
    await pumpRanks(tester, 1450);

    // Four completed ranks at 100%, five locked at 0%.
    expect(find.text('100%'), findsNWidgets(4));
    expect(find.text('0%'), findsNWidgets(5));
  });

  testWidgets('only the current rank shows a points-to-next line', (
    tester,
  ) async {
    await pumpRanks(tester, 1450);

    // Skilled Learner ends at 1799, so Advanced starts at 1800.
    expect(find.text('350 pts until next rank'), findsOneWidget);
  });

  testWidgets('the top rank says there is nothing left to climb', (
    tester,
  ) async {
    await pumpRanks(tester, 7500);

    expect(
      find.text('Highest rank reached — nothing left to climb'),
      findsOneWidget,
    );
    expect(find.textContaining('pts until next rank'), findsNothing);
  });

  testWidgets('the CURRENT badge is hidden, per the design default', (
    tester,
  ) async {
    await pumpRanks(tester, 1450);

    expect(kShowCurrentRankBadge, isFalse);
    expect(find.text('CURRENT'), findsNothing);
  });

  testWidgets('reached ranks are filled and later ones outlined', (
    tester,
  ) async {
    await pumpRanks(tester, 1450);

    // Tier 5 is current, so it and tiers 1-4 are filled; 6-10 are not.
    for (var tier = 1; tier <= 10; tier++) {
      final icon = tester.widget<RankIcon>(
        find.byKey(ValueKey('rank-icon-$tier')),
      );
      expect(icon.filled, tier <= 5, reason: 'tier $tier');
    }
  });

  testWidgets('an exact boundary promotes into the new rank', (tester) async {
    await pumpRanks(tester, 1200);

    // 1200 is Skilled Learner's own floor, so four ranks are complete.
    expect(find.text('COMPLETED'), findsNWidgets(4));
    expect(find.text('600 pts until next rank'), findsOneWidget);
  });

  testWidgets('renders without overflow at a narrow 320dp width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(home: RanksScreen(points: 123456)),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'the header is the shared ScreenHeader, the same height as Add '
    "course's own (title-only, no subtitle)",
    (tester) async {
      await pumpRanks(tester, 0);

      final headerFinder = find.byType(ScreenHeader);
      expect(headerFinder, findsOneWidget);
      final realHeight = tester.getSize(headerFinder).height;

      // Add course's own header is taller only because it also carries a
      // subtitle ('Create a course to organize your studies') — padding,
      // title style, button size and border radius are the exact same
      // ScreenHeader component either way, so the fair comparison is
      // against a title-only instance (no subtitle, matching this
      // screen), not Add course's actual subtitled height.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            // A Column, not a bare Scaffold.body: a lone body widget is
            // stretched to fill the whole screen, which would measure the
            // *screen's* height, not the header's own — a Column instead
            // gives a non-flexible child its natural content height, the
            // same as how the real screen actually uses it.
            body: Column(
              children: [
                ScreenHeader(
                  title: 'Add course',
                  backgroundColor: AppColors.navy,
                  onClose: () {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      final referenceHeight = tester.getSize(find.byType(ScreenHeader)).height;

      expect(realHeight, referenceHeight);
    },
  );

  testWidgets('the back chevron sits to the left of the title', (
    tester,
  ) async {
    await pumpRanks(tester, 0);

    final screenHeader = tester.widget<ScreenHeader>(
      find.byType(ScreenHeader),
    );
    expect(screenHeader.buttonOnStart, isTrue);

    final buttonX = tester
        .getTopLeft(find.byIcon(Icons.chevron_left))
        .dx;
    final titleX = tester.getTopLeft(find.text('Ranks')).dx;
    expect(buttonX, lessThan(titleX));
  });

  testWidgets('tapping the back chevron pops', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const RanksScreen(points: 0),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(RanksScreen), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();

    expect(find.byType(RanksScreen), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });
}
