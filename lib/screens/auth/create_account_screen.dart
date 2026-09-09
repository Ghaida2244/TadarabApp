import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../validators/auth_validators.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_error_banner.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/back_button_chip.dart';
import '../../widgets/password_strength_bar.dart';
import 'forgot_password_screen.dart';
import 'login_screen.dart';

/// A3 — Create Account, covering A3 default, A3b validation errors,
/// A3c email-already-taken, and A3d loading as states of one screen.
class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key, this.authService});

  /// Overridable for tests; defaults to the real Firebase-backed service.
  final AuthService? authService;

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  late final _authService = widget.authService ?? AuthService();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _emailFocus = FocusNode();

  bool _submitted = false;
  bool _emailTouched = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _loading = false;
  String? _serverErrorMessage;
  bool _emailTaken = false;

  @override
  void initState() {
    super.initState();
    _emailFocus.addListener(() {
      if (!_emailFocus.hasFocus) setState(() => _emailTouched = true);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _emailFocus.dispose();
    super.dispose();
  }

  String? get _nameError => _submitted && _nameController.text.trim().isEmpty
      ? 'Full name is required'
      : null;

  String? get _emailError {
    final email = _emailController.text.trim();
    if (_submitted && email.isEmpty) return 'Email is required';
    if ((_submitted || _emailTouched) &&
        email.isNotEmpty &&
        !AuthValidators.isValidEmailFormat(email)) {
      return 'Enter a valid email, like name@example.com';
    }
    return null;
  }

  String? get _passwordError {
    final password = _passwordController.text;
    if (_submitted && password.isEmpty) return 'Password is required';
    if (_submitted &&
        password.isNotEmpty &&
        !AuthValidators.isValidPassword(password)) {
      return 'Use at least 8 characters, including a number';
    }
    return null;
  }

  String? get _confirmError {
    final confirm = _confirmController.text;
    if (_submitted && confirm.isEmpty) return 'Please re-enter your password';
    if (_submitted &&
        confirm.isNotEmpty &&
        !AuthValidators.passwordsMatch(_passwordController.text, confirm)) {
      return "Passwords don't match";
    }
    return null;
  }

  AppFieldState _stateFor(String value, String? error) {
    if (error != null) return AppFieldState.error;
    if (value.isNotEmpty) return AppFieldState.filled;
    return AppFieldState.empty;
  }

  Future<void> _submit() async {
    setState(() {
      _submitted = true;
      _emailTouched = true;
    });
    if (_nameError != null ||
        _emailError != null ||
        _passwordError != null ||
        _confirmError != null) {
      return;
    }

    setState(() {
      _loading = true;
      _serverErrorMessage = null;
      _emailTaken = false;
    });
    try {
      await _authService.createAccount(
        name: _nameController.text,
        email: _emailController.text,
        password: _passwordController.text,
      );
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on AuthFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _serverErrorMessage = e.message;
        _emailTaken = e.isEmailTaken;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
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
              const SizedBox(height: 18),
              Text('Create Account', style: AppTypography.screenTitle),
              const SizedBox(height: 5),
              Text(
                'Start your learning journey today',
                style: AppTypography.subtitle,
              ),
              const SizedBox(height: 18),
              if (_serverErrorMessage != null) ...[
                AppErrorBanner(
                  heading: _emailTaken
                      ? 'An account already uses this email'
                      : 'Could not create your account',
                  body: _serverErrorMessage!,
                  actions: _emailTaken
                      ? [
                          GestureDetector(
                            onTap: () => Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) => const LoginScreen(),
                              ),
                            ),
                            child: Text(
                              'Log in instead',
                              style: AppTypography.link.copyWith(
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          GestureDetector(
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const ForgotPasswordScreen(),
                              ),
                            ),
                            child: Text(
                              'Reset password',
                              style: AppTypography.link.copyWith(
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ]
                      : null,
                ),
                const SizedBox(height: 14),
              ],
              AppTextField(
                label: 'Full name',
                hintText: 'Enter your name',
                controller: _nameController,
                leadingIcon: Icons.person_outline,
                enabled: !_loading,
                state: _stateFor(_nameController.text, _nameError),
                errorText: _nameError,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'Email',
                hintText: 'Enter your email',
                controller: _emailController,
                focusNode: _emailFocus,
                leadingIcon: Icons.mail_outline,
                keyboardType: TextInputType.emailAddress,
                enabled: !_loading,
                state: _stateFor(_emailController.text, _emailError),
                errorText: _emailError,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'Password',
                hintText: 'Create a password',
                controller: _passwordController,
                leadingIcon: Icons.lock_outline,
                obscureText: _obscurePassword,
                enabled: !_loading,
                state: _stateFor(_passwordController.text, _passwordError),
                trailing: GestureDetector(
                  onTap: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  child: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 19,
                    color: AppColors.textSecondary,
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSpacing.xs),
              if (_passwordController.text.isEmpty)
                if (_passwordError != null)
                  InlineFieldError(_passwordError!)
                else
                  Text(
                    'At least 8 characters, with a number.',
                    style: AppTypography.helper,
                  )
              else ...[
                PasswordStrengthBar(password: _passwordController.text),
                if (_passwordError != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  InlineFieldError(_passwordError!),
                ],
              ],
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'Re-enter password',
                hintText: 'Re-enter your password',
                controller: _confirmController,
                leadingIcon: Icons.lock_outline,
                obscureText: _obscureConfirm,
                enabled: !_loading,
                state: _stateFor(_confirmController.text, _confirmError),
                errorText: _confirmError,
                trailing:
                    AuthValidators.passwordsMatch(
                      _passwordController.text,
                      _confirmController.text,
                    )
                    ? const Icon(
                        Icons.check,
                        size: 19,
                        color: AppColors.success,
                      )
                    : GestureDetector(
                        onTap: () =>
                            setState(() => _obscureConfirm = !_obscureConfirm),
                        child: Icon(
                          _obscureConfirm
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 19,
                          color: AppColors.textSecondary,
                        ),
                      ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 24),
              AppButton(
                label: 'Create Account',
                loadingLabel: 'Creating your account…',
                loading: _loading,
                onPressed: _submit,
              ),
              const SizedBox(height: 18),
              GestureDetector(
                onTap: _loading
                    ? null
                    : () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      ),
                child: RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: AppTypography.footerBody.copyWith(
                      color: _loading ? AppColors.textOnDisabled : null,
                    ),
                    children: [
                      const TextSpan(text: 'Already have an account? '),
                      TextSpan(
                        text: 'Sign in',
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
    );
  }
}
