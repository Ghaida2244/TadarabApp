import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/screens/profile/ranks_screen.dart';
import 'package:tadarab_app/screens/profile/widgets/rank_icon.dart';
import 'package:tadarab_app/utils/rank.dart';

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
}
