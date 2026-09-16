import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/screens/auth/login_screen.dart';
import 'package:tadarab_app/services/auth_service.dart';

import '../helpers/fake_auth_service.dart';

void main() {
  Future<void> pumpLogin(
    WidgetTester tester, {
    AuthService? authService,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(authService: authService ?? FakeAuthService()),
      ),
    );
  }

  Future<void> enterEmailAndPassword(
    WidgetTester tester, {
    required String email,
    required String password,
  }) async {
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), email);
    await tester.enterText(fields.at(1), password);
  }

  group('A2 — default', () {
    testWidgets(
      'renders the email/password fields and Log In button, no errors',
      (tester) async {
        await pumpLogin(tester);

        expect(find.text('Welcome back'), findsOneWidget);
        expect(find.byType(TextField), findsNWidgets(2));
        expect(find.text('Log In'), findsOneWidget);
        expect(find.text('Email is required'), findsNothing);
        expect(find.text('Password is required'), findsNothing);
      },
    );
  });

  group('A2b — empty submit', () {
    testWidgets('shows required errors for both fields when submitted empty', (
      tester,
    ) async {
      await pumpLogin(tester);

      await tester.tap(find.text('Log In'));
      await tester.pump();

      expect(find.text('Email is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);
    });
  });

  group('A2c — invalid email on blur', () {
    testWidgets('does not show a format error before the field is touched', (
      tester,
    ) async {
      await pumpLogin(tester);

      await tester.enterText(find.byType(TextField).at(0), 'not-an-email');
      await tester.pump();

      expect(
        find.text('Enter a valid email, like name@example.com'),
        findsNothing,
      );
    });

    testWidgets('shows a format error once the email field loses focus', (
      tester,
    ) async {
      await pumpLogin(tester);

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'not-an-email');
      // Move focus to the password field, which blurs email.
      await tester.tap(fields.at(1));
      await tester.pump();

      expect(
        find.text('Enter a valid email, like name@example.com'),
        findsOneWidget,
      );
    });
  });

  group('A2e — loading', () {
    testWidgets('shows the signing-in spinner while the request is in flight', (
      tester,
    ) async {
      final fake = FakeAuthService(delay: const Duration(milliseconds: 300));
      await pumpLogin(tester, authService: fake);

      await enterEmailAndPassword(
        tester,
        email: 'student@example.com',
        password: 'abcdefg1',
      );
      await tester.tap(find.text('Log In'));
      await tester.pump();

      expect(find.text('logging in…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(fake.signInCalls, 1);

      await tester.pump(const Duration(milliseconds: 300));
    });
  });

  group('A2d — wrong credentials', () {
    testWidgets(
      'shows the wrong-credentials banner on kWrongCredentialsMessage',
      (tester) async {
        final fake = FakeAuthService(
          signInError: AuthFailure(kWrongCredentialsMessage),
        );
        await pumpLogin(tester, authService: fake);

        await enterEmailAndPassword(
          tester,
          email: 'student@example.com',
          password: 'abcdefg1',
        );
        await tester.tap(find.text('Log In'));
        await tester.pumpAndSettle();

        expect(find.text(kWrongCredentialsMessage), findsOneWidget);
        expect(
          find.text('Check them and try again, or reset your password.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'shows a distinct banner (not the wrong-credentials copy) for a network failure',
      (tester) async {
        final fake = FakeAuthService(
          signInError: AuthFailure(
            "Couldn't reach Tadarab. Check your connection and try again.",
          ),
        );
        await pumpLogin(tester, authService: fake);

        await enterEmailAndPassword(
          tester,
          email: 'student@example.com',
          password: 'abcdefg1',
        );
        await tester.tap(find.text('Log In'));
        await tester.pumpAndSettle();

        expect(
          find.text(
            "Couldn't reach Tadarab. Check your connection and try again.",
          ),
          findsOneWidget,
        );
        expect(find.text(kWrongCredentialsMessage), findsNothing);
      },
    );
  });

  group('success', () {
    testWidgets(
      'calls signIn with the entered credentials and pops back off the stack',
      (tester) async {
        final fake = FakeAuthService();
        // LoginScreen is always reached by being pushed on top of something
        // (Welcome, or the auth gate) — pump it that way here too, since its
        // success path pops back to the first route, which only actually
        // unmounts (and stops the loading state) when it isn't the first route.
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => LoginScreen(authService: fake),
                      ),
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        await enterEmailAndPassword(
          tester,
          email: 'student@example.com',
          password: 'abcdefg1',
        );
        await tester.tap(find.text('Log In'));
        await tester.pumpAndSettle();

        expect(fake.signInCalls, 1);
        expect(fake.lastSignInEmail, 'student@example.com');
        expect(find.byType(LoginScreen), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
