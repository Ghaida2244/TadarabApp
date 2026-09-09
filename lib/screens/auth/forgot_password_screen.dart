import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../validators/auth_validators.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_error_banner.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/back_button_chip.dart';
import 'check_email_screen.dart';
import 'create_account_screen.dart';

/// A4 — Forgot Password. Covers states A (default) and B (live email-format
/// check while typing) on this screen; state C ("Check your email") is a
/// separate screen ([CheckEmailScreen]) pushed after a successful send.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.authService});

  /// Overridable for tests; defaults to the real Firebase-backed service.
  final AuthService? authService;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final _authService = widget.authService ?? AuthService();
  final _emailController = TextEditingController();

  bool _submitted = false;
  bool _loading = false;
  String? _sendErrorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  bool get _isValidFormat =>
      AuthValidators.isValidEmailFormat(_emailController.text.trim());

  String? get _emailError {
    if (!_submitted) return null;
    if (_emailController.text.trim().isEmpty) return 'Email is required';
    if (!_isValidFormat) return 'Enter a valid email, like name@example.com';
    return null;
  }

  AppFieldState get _fieldState {
    if (_emailError != null) return AppFieldState.error;
    if (_isValidFormat) return AppFieldState.success;
    return AppFieldState.empty;
  }

  Future<void> _submit() async {
    setState(() => _submitted = true);
    if (_emailError != null) return;

    setState(() {
      _loading = true;
      _sendErrorMessage = null;
    });
    final email = _emailController.text.trim();
    try {
      await _authService.sendPasswordReset(email: email);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              CheckEmailScreen(email: email, authService: widget.authService),
        ),
      );
      setState(() => _loading = false);
    } on AuthFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _sendErrorMessage = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xxl,
            AppSpacing.xl,
            AppSpacing.xxl,
            AppSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BackButtonChip(
                onTap: () => Navigator.of(context).pop(),
                enabled: !_loading,
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        Text(
                          'Forgot password',
                          style: AppTypography.screenTitle,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Enter the email on your account and we'll send you a reset link.",
                          textAlign: TextAlign.center,
                          style: AppTypography.subtitle,
                        ),
                        const SizedBox(height: 20),
                        if (_sendErrorMessage != null) ...[
                          AppErrorBanner(
                            heading: 'Could not send the reset link',
                            body: _sendErrorMessage!,
                          ),
                          const SizedBox(height: 16),
                        ],
                        AppTextField(
                          label: 'Email',
                          hintText: 'Enter your email',
                          controller: _emailController,
                          leadingIcon: Icons.mail_outline,
                          keyboardType: TextInputType.emailAddress,
                          enabled: !_loading,
                          state: _fieldState,
                          errorText: _emailError,
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 20),
                        AppButton(
                          label: 'Send reset link',
                          variant: AppButtonVariant.accent,
                          loading: _loading,
                          onPressed: _submit,
                        ),
                        if (_isValidFormat) ...[
                          const SizedBox(height: 20),
                          GestureDetector(
                            onTap: _loading
                                ? null
                                : () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const CreateAccountScreen(),
                                    ),
                                  ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Need an account? ',
                                  style: AppTypography.footerBody,
                                ),
                                Text('Create one', style: AppTypography.link),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        GestureDetector(
                          onTap: _loading
                              ? null
                              : () => Navigator.of(context).pop(),
                          child: RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              style: AppTypography.footerBody.copyWith(
                                color: _loading
                                    ? AppColors.textOnDisabled
                                    : null,
                              ),
                              children: [
                                const TextSpan(
                                  text: 'Remember your password? ',
                                ),
                                TextSpan(
                                  text: 'Back to log in',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: _loading
                                        ? AppColors.textOnDisabled
                                        : AppColors.red,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
