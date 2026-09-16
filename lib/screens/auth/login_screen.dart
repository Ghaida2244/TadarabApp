import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../validators/auth_validators.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_error_banner.dart';
import '../../widgets/app_text_field.dart';
import 'create_account_screen.dart';
import 'forgot_password_screen.dart';

/// A2 — Log in, covering every state from the design (A2 default, A2b empty
/// submit, A2c invalid-email-on-blur, A2d wrong credentials, A2e loading)
/// as local state on one screen rather than five separate widgets.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.authService});

  /// Overridable for tests; defaults to the real Firebase-backed service.
  final AuthService? authService;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final _authService = widget.authService ?? AuthService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus = FocusNode();

  bool _submitted = false;
  bool _emailTouched = false;
  bool _obscurePassword = true;
  bool _loading = false;
  String? _serverErrorMessage;

  @override
  void initState() {
    super.initState();
    _emailFocus.addListener(() {
      if (!_emailFocus.hasFocus) setState(() => _emailTouched = true);
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    super.dispose();
  }

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
    if (_submitted && _passwordController.text.isEmpty) {
      return 'Password is required';
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
    if (_emailError != null || _passwordError != null) return;

    setState(() {
      _loading = true;
      _serverErrorMessage = null;
    });
    try {
      await _authService.signIn(
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
            children: [
              const SizedBox(height: 20),
              Image.asset(
                'assets/images/tadarab_logo.png',
                width: 145,
                height: 135,
              ),
              const SizedBox(height: 12),
              Text('Welcome back', style: AppTypography.screenTitleCompact),
              const SizedBox(height: 8),
              Text(
                'Log in to continue your learning journey',
                style: AppTypography.subtitle,
              ),
              const SizedBox(height: 22),
              if (_serverErrorMessage != null) ...[
                AppErrorBanner(
                  heading: _serverErrorMessage == kWrongCredentialsMessage
                      ? kWrongCredentialsMessage
                      : "Couldn't sign in",
                  body: _serverErrorMessage == kWrongCredentialsMessage
                      ? 'Check them and try again, or reset your password.'
                      : _serverErrorMessage!,
                ),
                const SizedBox(height: 20),
              ],
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
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                label: 'Password',
                hintText: 'Enter your password',
                controller: _passwordController,
                leadingIcon: Icons.lock_outline,
                obscureText: _obscurePassword,
                enabled: !_loading,
                state: _stateFor(_passwordController.text, _passwordError),
                errorText: _passwordError,
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
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: _loading
                      ? null
                      : () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ForgotPasswordScreen(),
                          ),
                        ),
                  child: Text('Forgot password?', style: AppTypography.link),
                ),
              ),
              const SizedBox(height: 22),
              AppButton(
                label: 'Log In',
                loadingLabel: 'logging in…',
                loading: _loading,
                onPressed: _submit,
              ),
              const SizedBox(height: 18),
              GestureDetector(
                onTap: _loading
                    ? null
                    : () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const CreateAccountScreen(),
                        ),
                      ),
                child: RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: AppTypography.footerBody.copyWith(
                      color: _loading ? AppColors.textOnDisabled : null,
                    ),
                    children: [
                      const TextSpan(text: 'New to Tadarab? '),
                      TextSpan(
                        text: 'Create an account',
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
