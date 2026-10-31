import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/theme/app_theme.dart';
import 'package:tadarab_app/widgets/color_swatch_tile.dart';

void main() {
  Future<void> pumpSwatch(
    WidgetTester tester, {
    bool selected = false,
    bool locked = false,
    VoidCallback? onTap,
    VoidCallback? onRemove,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ColorSwatchTile(
            color: const Color(0xFF16A34A),
            hex: '#16A34A',
            selected: selected,
            locked: locked,
            onTap: onTap ?? () {},
            onRemove: onRemove,
          ),
        ),
      ),
    );
  }

  Future<void> pumpCustom(
    WidgetTester tester, {
    bool selected = false,
    VoidCallback? onTap,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomColorSwatchTile(
            selected: selected,
            onTap: onTap ?? () {},
          ),
        ),
      ),
    );
  }

  group('ColorSwatchTile', () {
    testWidgets('exposes "Color #RRGGBB" as its accessibility label', (
      tester,
    ) async {
      await pumpSwatch(tester);

      expect(find.bySemanticsLabel('Color #16A34A'), findsOneWidget);
    });

    testWidgets('exposes the selected state to Semantics', (tester) async {
      Semantics semanticsOf(WidgetTester tester) => tester.widget<Semantics>(
        find
            .descendant(
              of: find.byType(ColorSwatchTile),
              matching: find.byType(Semantics),
            )
            .first,
      );

      await pumpSwatch(tester, selected: false);
      expect(semanticsOf(tester).properties.selected, isFalse);

      await pumpSwatch(tester, selected: true);
      expect(semanticsOf(tester).properties.selected, isTrue);
    });

    testWidgets('shows a check only when selected', (tester) async {
      await pumpSwatch(tester, selected: false);
      expect(find.byIcon(Icons.check), findsNothing);

      await pumpSwatch(tester, selected: true);
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('a locked tile shows a lock "x" and ignores taps', (
      tester,
    ) async {
      var tapped = false;
      await pumpSwatch(tester, locked: true, onTap: () => tapped = true);
      await tester.tap(find.byType(ColorSwatchTile));
      await tester.pump();

      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(tapped, isFalse);
    });

    testWidgets('an unlocked tile responds to taps', (tester) async {
      var tapped = false;
      await pumpSwatch(tester, onTap: () => tapped = true);
      await tester.tap(find.byType(ColorSwatchTile));

      expect(tapped, isTrue);
    });

    Border borderOf(WidgetTester tester) =>
        (tester
                    .widget<Container>(
                      find
                          .descendant(
                            of: find.byType(ColorSwatchTile),
                            matching: find.byType(Container),
                          )
                          .first,
                    )
                    .decoration!
                as BoxDecoration)
            .border! as Border;

    testWidgets(
      'the selected border is thinner than 3px and softer than full '
      'opacity navy',
      (tester) async {
        await pumpSwatch(tester, selected: true);

        final border = borderOf(tester);
        expect(border.top.width, lessThan(3));
        expect(border.top.color, AppColors.navy.withValues(alpha: 0.75));
        expect(border.top.color.a, lessThan(1));
      },
    );

    testWidgets('an unselected tile keeps a fully transparent border', (
      tester,
    ) async {
      await pumpSwatch(tester, selected: false);

      expect(borderOf(tester).top.color, Colors.transparent);
    });

    testWidgets('shows no remove badge when onRemove is omitted', (
      tester,
    ) async {
      await pumpSwatch(tester);

      expect(find.bySemanticsLabel('Remove color #16A34A'), findsNothing);
    });

    testWidgets('shows a remove badge with its own label when given', (
      tester,
    ) async {
      await pumpSwatch(tester, onRemove: () {});

      expect(find.bySemanticsLabel('Remove color #16A34A'), findsOneWidget);
    });

    testWidgets('tapping the badge calls onRemove, not onTap', (
      tester,
    ) async {
      var tapped = false;
      var removed = false;
      await pumpSwatch(
        tester,
        onTap: () => tapped = true,
        onRemove: () => removed = true,
      );

      await tester.tap(find.bySemanticsLabel('Remove color #16A34A'));

      expect(removed, isTrue);
      expect(tapped, isFalse);
    });

    testWidgets('the badge does not block the rest of the tile from being tapped', (
      tester,
    ) async {
      var tapped = false;
      await pumpSwatch(
        tester,
        onTap: () => tapped = true,
        onRemove: () {},
      );

      await tester.tap(find.byType(ColorSwatchTile));

      expect(tapped, isTrue);
    });
  });

  group('CustomColorSwatchTile', () {
    testWidgets('exposes "Custom color" as its accessibility label', (
      tester,
    ) async {
      await pumpCustom(tester);

      expect(find.bySemanticsLabel('Custom color'), findsOneWidget);
    });

    testWidgets('exposes the selected state to Semantics', (tester) async {
      Semantics semanticsOf(WidgetTester tester) => tester.widget<Semantics>(
        find
            .descendant(
              of: find.byType(CustomColorSwatchTile),
              matching: find.byType(Semantics),
            )
            .first,
      );

      await pumpCustom(tester, selected: false);
      expect(semanticsOf(tester).properties.selected, isFalse);

      await pumpCustom(tester, selected: true);
      expect(semanticsOf(tester).properties.selected, isTrue);
    });

    testWidgets('responds to taps', (tester) async {
      var tapped = false;
      await pumpCustom(tester, onTap: () => tapped = true);
      await tester.tap(find.byType(CustomColorSwatchTile));

      expect(tapped, isTrue);
    });

    Border borderOf(WidgetTester tester) =>
        (tester
                    .widget<Container>(
                      find
                          .descendant(
                            of: find.byType(CustomColorSwatchTile),
                            matching: find.byType(Container),
                          )
                          .first,
                    )
                    .decoration!
                as BoxDecoration)
            .border! as Border;

    testWidgets(
      'the selected border matches ColorSwatchTile\'s: thinner than 3px, '
      'softer than full opacity navy',
      (tester) async {
        await pumpCustom(tester, selected: true);

        final border = borderOf(tester);
        expect(border.top.width, lessThan(3));
        expect(border.top.color, AppColors.navy.withValues(alpha: 0.75));
      },
    );

    testWidgets('an unselected tile keeps a fully transparent border', (
      tester,
    ) async {
      await pumpCustom(tester, selected: false);

      expect(borderOf(tester).top.color, Colors.transparent);
    });
  });
}
