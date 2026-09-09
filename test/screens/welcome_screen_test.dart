import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/screens/auth/create_account_screen.dart';
import 'package:tadarab_app/screens/auth/login_screen.dart';
import 'package:tadarab_app/screens/auth/welcome_screen.dart';
import 'package:tadarab_app/theme/app_theme.dart';

/// Covers what doesn't require a real Firebase app: WelcomeScreen has no
/// AuthService, so it's the one auth screen safely pumpable in a plain
/// widget test. The other auth screens construct AuthService (which touches
/// FirebaseAuth.instance) at State-init time and aren't covered here.
void main() {
  Future<void> pumpWelcome(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(theme: null, home: WelcomeScreen()),
    );
  }

  testWidgets('shows the logo, tagline and both entry buttons', (tester) async {
    await pumpWelcome(tester);

    expect(find.text('Study smarter, not longer'), findsOneWidget);
    expect(find.text('Log In'), findsOneWidget);
    expect(find.text('Create Account'), findsOneWidget);
  });

  testWidgets('Log In navigates to LoginScreen', (tester) async {
    await pumpWelcome(tester);

    await tester.tap(find.text('Log In'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('Create Account navigates to CreateAccountScreen', (
    tester,
  ) async {
    await pumpWelcome(tester);

    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();

    expect(find.byType(CreateAccountScreen), findsOneWidget);
  });

  testWidgets('renders with AppTheme without layout errors', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.themeData, home: const WelcomeScreen()),
    );
    expect(tester.takeException(), isNull);
  });
}
