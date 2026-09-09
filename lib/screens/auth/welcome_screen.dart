import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';
import 'create_account_screen.dart';
import 'login_screen.dart';

/// A1 — the entry point: logo, tagline, and the two ways into the app.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xxl,
            0,
            AppSpacing.xxl,
            AppSpacing.xxxl,
          ),
          child: Column(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/images/tadarab_logo.png',
                      width: 254,
                      height: 248,
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'Study smarter, not longer',
                      style: AppTypography.promoTitle,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your lectures, your questions, your pace.',
                      textAlign: TextAlign.center,
                      style: AppTypography.subtitle,
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  AppButton(
                    label: 'Log In',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: 'Create Account',
                    variant: AppButtonVariant.outlinedBrand,
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const CreateAccountScreen(),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
