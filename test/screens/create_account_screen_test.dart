import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/screens/auth/create_account_screen.dart';
import 'package:tadarab_app/services/auth_service.dart';

import '../helpers/fake_auth_service.dart';

void main() {
  Future<void> pumpCreateAccount(
    WidgetTester tester, {
    AuthService? authService,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CreateAccountScreen(
          authService: authService ?? FakeAuthService(),
        ),
      ),
    );
  }

  Future<void> fillForm(
    WidgetTester tester, {
    String name = 'Ghaida A.',
    String email = 'ghaida@example.com',
    String password = 'abcdefg1',
    String confirm = 'abcdefg1',
  }) async {
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), name);
    await tester.enterText(fields.at(1), email);
    await tester.enterText(fields.at(2), password);
    await tester.enterText(fields.at(3), confirm);
  }

  // The form can be taller than the test viewport, so the submit button may
  // start out below the fold — scroll it into view before tapping, rather
  // than relying on it happening to already be on-screen.
  Future<void> submit(WidgetTester tester) async {
    final button = find.text('Create Account').last;
    await tester.ensureVisible(button);
    await tester.tap(button);
  }

  group('A3 — default', () {
    testWidgets('renders all four fields, the hint text, and no errors', (
      tester,
    ) async {
      await pumpCreateAccount(tester);

      expect(find.text('Create Account'), findsWidgets);
      expect(find.byType(TextField), findsNWidgets(4));
      expect(
        find.text('At least 8 characters, with a number.'),
        findsOneWidget,
      );
      expect(find.text('Full name is required'), findsNothing);
    });
  });

  group('A3b — validation errors', () {
    testWidgets('empty submit shows a required error for every field', (
      tester,
    ) async {
      await pumpCreateAccount(tester);

      await submit(tester);
      await tester.pump();

      expect(find.text('Full name is required'), findsOneWidget);
      expect(find.text('Email is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);
      expect(find.text('Please re-enter your password'), findsOneWidget);
    });

    testWidgets(
      'bad email, weak password, and mismatched confirm all show their own error',
      (tester) async {
        await pumpCreateAccount(tester);

        await fillForm(
          tester,
          email: 'ghaida@tadarab',
          password: 'ghaida',
          confirm: 'somethingelse',
        );
        await submit(tester);
        await tester.pump();

        expect(
          find.text('Enter a valid email, like name@example.com'),
          findsOneWidget,
        );
        expect(
          find.text('Use at least 8 characters, including a number'),
          findsOneWidget,
        );
        expect(find.text("Passwords don't match"), findsOneWidget);
        expect(find.text('Weak'), findsOneWidget);
      },
    );

    testWidgets('a long varied password shows Strong on the strength bar', (
      tester,
    ) async {
      await pumpCreateAccount(tester);

      await tester.enterText(find.byType(TextField).at(2), 'Abcdefgh1!');
      await tester.pump();

      expect(find.text('Strong'), findsOneWidget);
    });
  });

  group('A3c — email already taken', () {
    testWidgets('shows the taken-email banner with both action links', (
      tester,
    ) async {
      final fake = FakeAuthService(
        createAccountError: AuthFailure(
          'ghaida@example.com is already registered.',
          isEmailTaken: true,
        ),
      );
      await pumpCreateAccount(tester, authService: fake);

      await fillForm(tester);
      await submit(tester);
      await tester.pumpAndSettle();

      expect(find.text('An account already uses this email'), findsOneWidget);
      expect(find.text('Log in instead'), findsOneWidget);
      expect(find.text('Reset password'), findsOneWidget);
    });
  });

  group('A3d — loading', () {
    testWidgets(
      'shows the creating-account spinner while the request is in flight',
      (tester) async {
        final fake = FakeAuthService(delay: const Duration(milliseconds: 300));
        await pumpCreateAccount(tester, authService: fake);

        await fillForm(tester);
        await submit(tester);
        await tester.pump();

        expect(find.text('Creating your account…'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(fake.createAccountCalls, 1);

        await tester.pump(const Duration(milliseconds: 300));
      },
    );
  });

  group('success', () {
    testWidgets('calls createAccount and pops back off the stack', (
      tester,
    ) async {
      final fake = FakeAuthService();
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CreateAccountScreen(authService: fake),
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

      await fillForm(tester);
      await submit(tester);
      await tester.pumpAndSettle();

      expect(fake.createAccountCalls, 1);
      expect(find.byType(CreateAccountScreen), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
