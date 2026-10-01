import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/features/flashcards/widgets/progress_pips.dart';
import 'package:tadarab_app/models/enums.dart';
import 'package:tadarab_app/theme/app_theme.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

Color _colorOfPip(WidgetTester tester, int index) {
  final container = tester.widget<Container>(
    find.byKey(ValueKey('pip-$index')),
  );
  return (container.decoration as BoxDecoration).color!;
}

void main() {
  testWidgets('shows all four pip states: current, known, needs-review, '
      'and not-yet-reached', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const ProgressPips(
          total: 4,
          currentIndex: 2,
          statuses: [
            ReviewStatus.knowIt,
            ReviewStatus.needsReview,
            null,
            null,
          ],
        ),
      ),
    );

    // Colors per Tadarab Phase 2b - Flashcards.dc.html's `pips` mapping —
    // rendered against the navy header, so "needs review"/"untouched" are
    // translucent white rather than opaque greys.
    expect(_colorOfPip(tester, 0), const Color(0xFF7BE0A0));
    expect(_colorOfPip(tester, 1), const Color(0xBFFFFFFF));
    expect(_colorOfPip(tester, 2), AppColors.red);
    expect(_colorOfPip(tester, 3), const Color(0x38FFFFFF));
  });
}
