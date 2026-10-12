import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/theme/app_theme.dart';
import 'package:tadarab_app/widgets/app_text_field.dart';

void main() {
  Future<void> pump(WidgetTester tester, {required bool obscureText}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppTextField(
            label: 'Password',
            hintText: 'Enter your password',
            controller: TextEditingController(),
            leadingIcon: Icons.lock_outline,
            obscureText: obscureText,
          ),
        ),
      ),
    );
  }

  testWidgets(
    'an obscured field\'s hint has no letter spacing, while the typed '
    'style keeps its wide spacing for the password dots',
    (tester) async {
      await pump(tester, obscureText: true);

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.decoration!.hintStyle!.letterSpacing, 0);
      expect(field.style!.letterSpacing, AppTypography.fieldPassword.letterSpacing);
      expect(field.style!.fontSize, AppTypography.fieldPassword.fontSize);
    },
  );

  testWidgets(
    'a non-obscured field\'s hint and typed style both have no extra '
    'letter spacing',
    (tester) async {
      await pump(tester, obscureText: false);

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.decoration!.hintStyle!.letterSpacing, 0);
      expect(field.style!.letterSpacing, AppTypography.fieldInput.letterSpacing);
    },
  );
}
