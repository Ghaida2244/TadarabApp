import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/screens/auth/check_email_screen.dart';
import 'package:tadarab_app/screens/auth/forgot_password_screen.dart';
import 'package:tadarab_app/services/auth_service.dart';

import '../helpers/fake_auth_service.dart';

void main() {
  Future<void> pumpForgotPassword(
    WidgetTester tester, {
    AuthService? authService,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ForgotPasswordScreen(
          authService: authService ?? FakeAuthService(),
        ),
      ),
    );
  }

  group('A4 — default', () {
    testWidgets('renders the email field and Send reset link, no errors', (
      tester,
    ) async {
      await pumpForgotPassword(tester);

      expect(find.text('Forgot password'), findsOneWidget);
      expect(find.text('Send reset link'), findsOneWidget);
      expect(find.text('Email is required'), findsNothing);
      // "Need an account?" only shows once the email format is valid.
      expect(find.text('Need an account? '), findsNothing);
    });

    testWidgets('empty submit shows a required error', (tester) async {
      await pumpForgotPassword(tester);

      await tester.tap(find.text('Send reset link'));
      await tester.pump();

      expect(find.text('Email is required'), findsOneWidget);
    });

    testWidgets('submitting a badly-formatted email shows a format error', (
      tester,
    ) async {
      await pumpForgotPassword(tester);

      await tester.enterText(find.byType(TextField), 'not-an-email');
      await tester.tap(find.text('Send reset link'));
      await tester.pump();

      expect(
        find.text('Enter a valid email, like name@example.com'),
        findsOneWidget,
      );
    });
  });

  group('A4b — live email format validation', () {
    testWidgets(
      'a valid-format email reveals the "Need an account?" link before submitting',
      (tester) async {
        await pumpForgotPassword(tester);

        await tester.enterText(find.byType(TextField), 'ghaida@ku.edu');
        await tester.pump();

        expect(find.text('Need an account? '), findsOneWidget);
        // Never submitted, so this must be live formatting feedback, not a send-result state.
        expect(find.text('Email is required'), findsNothing);
      },
    );

    testWidgets('an incomplete email does not reveal the link', (tester) async {
      await pumpForgotPassword(tester);

      await tester.enterText(find.byType(TextField), 'ghaida@');
      await tester.pump();

      expect(find.text('Need an account? '), findsNothing);
    });
  });

  group('loading', () {
    testWidgets('shows a spinner on the button while sending', (tester) async {
      final fake = FakeAuthService(delay: const Duration(milliseconds: 300));
      await pumpForgotPassword(tester, authService: fake);

      await tester.enterText(find.byType(TextField), 'ghaida@ku.edu');
      await tester.tap(find.text('Send reset link'));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(fake.sendPasswordResetCalls, 1);

      await tester.pump(const Duration(milliseconds: 300));
    });
  });

  group('send failure', () {
    testWidgets(
      'shows an inline banner on a real send error (e.g. network failure)',
      (tester) async {
        final fake = FakeAuthService(
          sendPasswordResetError: AuthFailure(
            "Couldn't reach Tadarab. Check your connection and try again.",
          ),
        );
        await pumpForgotPassword(tester, authService: fake);

        await tester.enterText(find.byType(TextField), 'ghaida@ku.edu');
        await tester.tap(find.text('Send reset link'));
        await tester.pumpAndSettle();

        expect(find.text('Could not send the reset link'), findsOneWidget);
        expect(
          find.text(
            "Couldn't reach Tadarab. Check your connection and try again.",
          ),
          findsOneWidget,
        );
      },
    );
  });

  group('A4c — success routes to Check your email', () {
    testWidgets(
      'a successful send pushes CheckEmailScreen with the entered email',
      (tester) async {
        final fake = FakeAuthService();
        await pumpForgotPassword(tester, authService: fake);

        await tester.enterText(find.byType(TextField), 'ghaida@ku.edu');
        await tester.tap(find.text('Send reset link'));
        await tester.pumpAndSettle();

        expect(find.byType(CheckEmailScreen), findsOneWidget);
        expect(
          find.textContaining('ghaida@ku.edu', findRichText: true),
          findsOneWidget,
        );
        expect(fake.lastResetEmail, 'ghaida@ku.edu');

        // CheckEmailScreen runs a 60s cooldown Timer.periodic — dispose it
        // cleanly instead of leaving a pending timer at test teardown.
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  });
}
