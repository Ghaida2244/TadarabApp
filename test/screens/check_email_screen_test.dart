import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/screens/auth/check_email_screen.dart';
import 'package:tadarab_app/screens/auth/login_screen.dart';
import 'package:tadarab_app/services/auth_service.dart';
import 'package:tadarab_app/theme/app_theme.dart';
import 'package:tadarab_app/widgets/app_button.dart';

import '../helpers/fake_auth_service.dart';

Color _borderColorOf(WidgetTester tester, String label) {
  final container = tester.widget<AnimatedContainer>(
    find.descendant(
      of: find.widgetWithText(AppButton, label),
      matching: find.byType(AnimatedContainer),
    ),
  );
  return (container.decoration as BoxDecoration).border!.top.color;
}

void main() {
  Future<void> pumpCheckEmail(
    WidgetTester tester, {
    AuthService? authService,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CheckEmailScreen(
          email: 'ghaida@tadarab.com',
          authService: authService ?? FakeAuthService(),
        ),
      ),
    );
  }

  group('A4c — on cooldown', () {
    testWidgets(
      'shows the never-leaks-existence message and a disabled Resend link',
      (tester) async {
        await pumpCheckEmail(tester);

        expect(find.text('Check your email'), findsOneWidget);
        expect(
          find.textContaining(
            'If an account exists, a reset link was sent to',
            findRichText: true,
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining('ghaida@tadarab.com', findRichText: true),
          findsOneWidget,
        );
        // At the very first frame (60s left) this must read "1:00", not the
        // invalid "0:60".
        expect(find.textContaining('resend in 1:00'), findsOneWidget);

        final resendButton = tester.widget<GestureDetector>(
          find
              .ancestor(
                of: find.text('Resend link'),
                matching: find.byType(GestureDetector),
              )
              .first,
        );
        expect(resendButton.onTap, isNull);

        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets('Resend link keeps the dim look while disabled on cooldown', (
      tester,
    ) async {
      await pumpCheckEmail(tester);

      // The disabled look is outlinedNeutral's own default border — the
      // active override never applies while onPressed is null.
      expect(_borderColorOf(tester, 'Resend link'), AppColors.borderDefault);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('counts down each second', (tester) async {
      await pumpCheckEmail(tester);

      await tester.pump(const Duration(seconds: 5));

      expect(find.textContaining('resend in 0:55'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('cooldown expired', () {
    testWidgets('drops the countdown text and enables Resend link', (
      tester,
    ) async {
      await pumpCheckEmail(tester);

      await tester.pump(const Duration(seconds: 61));

      expect(find.text('Nothing yet? Check spam.'), findsOneWidget);
      final resendButton = tester.widget<GestureDetector>(
        find
            .ancestor(
              of: find.text('Resend link'),
              matching: find.byType(GestureDetector),
            )
            .first,
      );
      expect(resendButton.onTap, isNotNull);
    });

    testWidgets('Resend link looks active once the cooldown expires', (
      tester,
    ) async {
      await pumpCheckEmail(tester);

      await tester.pump(const Duration(seconds: 61));

      expect(
        _borderColorOf(tester, 'Resend link'),
        AppColors.navy.withValues(alpha: 0.32),
      );
    });

    testWidgets(
      'Resend link falls back to the dim loading look while the request '
      'is in flight, not the active look',
      (tester) async {
        final fake = FakeAuthService(delay: const Duration(seconds: 1));
        await pumpCheckEmail(tester, authService: fake);

        await tester.pump(const Duration(seconds: 61));
        await tester.tap(find.text('Resend link'));
        await tester.pump();

        // AppButton's loading look has no border at all — confirming the
        // active override isn't leaking into it.
        final container = tester.widget<AnimatedContainer>(
          find.descendant(
            of: find.widgetWithText(AppButton, 'Resend link'),
            matching: find.byType(AnimatedContainer),
          ),
        );
        expect((container.decoration as BoxDecoration).border, isNull);

        await tester.pump(const Duration(seconds: 1));
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets(
      'tapping Resend calls sendPasswordReset again and restarts the cooldown',
      (tester) async {
        final fake = FakeAuthService();
        await pumpCheckEmail(tester, authService: fake);

        await tester.pump(const Duration(seconds: 61));
        await tester.tap(find.text('Resend link'));
        await tester.pumpAndSettle();

        expect(fake.sendPasswordResetCalls, 1);
        expect(fake.lastResetEmail, 'ghaida@tadarab.com');
        expect(find.textContaining('resend in 1:00'), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets('shows an inline error if the resend itself fails', (
      tester,
    ) async {
      final fake = FakeAuthService(
        sendPasswordResetError: AuthFailure(
          "Couldn't reach Tadarab. Check your connection and try again.",
        ),
      );
      await pumpCheckEmail(tester, authService: fake);

      await tester.pump(const Duration(seconds: 61));
      await tester.tap(find.text('Resend link'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          "Couldn't reach Tadarab. Check your connection and try again.",
        ),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('navigation', () {
    testWidgets('Back to log in clears the stack down to LoginScreen', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CheckEmailScreen(
                      email: 'a@b.com',
                      authService: FakeAuthService(),
                    ),
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

      await tester.tap(find.text('Back to log in'));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(CheckEmailScreen), findsNothing);
    });
  });
}
