import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('bundled Nunito font', () {
    test('the font asset is bundled and is a real TrueType file', () async {
      final data = await rootBundle.load(
        'assets/fonts/Nunito-VariableFont_wght.ttf',
      );
      expect(data.lengthInBytes, greaterThan(50000));
      // TrueType magic number: 0x00010000.
      expect(data.getUint32(0), 0x00010000);
    });

    test('AppTheme wires Nunito into fontFamily and the text theme', () {
      final theme = AppTheme.themeData;
      expect(theme.textTheme.bodyMedium?.fontFamily, 'Nunito');
      expect(theme.textTheme.titleLarge?.fontFamily, 'Nunito');
    });

    test('every AppTypography style is Nunito', () {
      final styles = <TextStyle>[
        AppTypography.display,
        AppTypography.screenTitle,
        AppTypography.screenTitleCompact,
        AppTypography.promoTitle,
        AppTypography.button,
        AppTypography.buttonSecondary,
        AppTypography.fieldInput,
        AppTypography.fieldPassword,
        AppTypography.subtitle,
        AppTypography.fieldLabel,
        AppTypography.helper,
        AppTypography.link,
        AppTypography.footerBody,
        AppTypography.strengthLabel,
        AppTypography.bannerHeading,
        AppTypography.bannerBody,
        AppTypography.eyebrow,
      ];
      for (final style in styles) {
        expect(
          style.fontFamily,
          'Nunito',
          reason: 'style $style is not Nunito',
        );
      }
    });

    testWidgets(
      'a plain Text under the theme resolves to Nunito (bare TextStyle inherits it)',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.themeData,
            home: const Scaffold(
              body: Text(
                'sample',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
            ),
          ),
        );

        final richText = tester.widget<RichText>(find.byType(RichText).first);
        expect((richText.text as TextSpan).style?.fontFamily, 'Nunito');
      },
    );
  });

  group('screen backgrounds', () {
    test('the default scaffold background is pure white (#FFFFFF) — the auth screens', () {
      expect(
        AppTheme.themeData.scaffoldBackgroundColor,
        const Color(0xFFFFFFFF),
      );
      expect(AppColors.background, const Color(0xFFFFFFFF));
    });

    test('Home overrides with its own near-white background', () {
      expect(AppColors.homeBackground, const Color(0xFFF7F8FD));
    });
  });
}
