import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/back_button_chip.dart';
import 'login_screen.dart';

const _resendCooldown = Duration(seconds: 60);

/// A4c — "Check your email". Shown after a successful (or account-doesn't-
/// exist, which looks identical) password reset request. Deliberately
/// never reveals whether [email] is actually registered.
class CheckEmailScreen extends StatefulWidget {
  const CheckEmailScreen({super.key, required this.email, this.authService});

  final String email;

  /// Overridable for tests; defaults to the real Firebase-backed service.
  final AuthService? authService;

  @override
  State<CheckEmailScreen> createState() => _CheckEmailScreenState();
}

class _CheckEmailScreenState extends State<CheckEmailScreen> {
  late final _authService = widget.authService ?? AuthService();
  late int _secondsRemaining = _resendCooldown.inSeconds;
  Timer? _timer;
  bool _resending = false;
  String? _resendErrorMessage;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _secondsRemaining = _resendCooldown.inSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining <= 1) {
        timer.cancel();
        setState(() => _secondsRemaining = 0);
      } else {
        setState(() => _secondsRemaining--);
      }
    });
  }

  Future<void> _resend() async {
    setState(() {
      _resending = true;
      _resendErrorMessage = null;
    });
    try {
      await _authService.sendPasswordReset(email: widget.email);
      if (!mounted) return;
      setState(() => _resending = false);
      _startCooldown();
    } on AuthFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _resending = false;
        _resendErrorMessage = e.message;
      });
    }
  }

  /// "m:ss", matching the mockup's "0:42" — handled generally (not hardcoded
  /// to a leading "0:") so a cooldown of a full minute or more, e.g. the
  /// very first frame at 60s, doesn't render as the invalid "0:60".
  String _formatCooldown(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  void _backToLogIn() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    final onCooldown = _secondsRemaining > 0;
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
              BackButtonChip(onTap: _backToLogIn),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: AppColors.successBackgroundStrong,
                          borderRadius: BorderRadius.circular(32),
                        ),
                        child: const Icon(
                          Icons.mail_outline,
                          size: 46,
                          color: AppColors.success,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Check your email',
                        style: AppTypography.screenTitleCompact,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: AppTypography.subtitle.copyWith(height: 1.6),
                          children: [
                            const TextSpan(
                              text: 'If an account exists, a reset link was sent to ',
                            ),
                            TextSpan(
                              text: widget.email,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                color: AppColors.navy,
                              ),
                            ),
                            const TextSpan(text: '.'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 11,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.warningBackground,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.schedule,
                              size: 17,
                              color: AppColors.warningText,
                            ),
                            const SizedBox(width: 9),
                            Flexible(
                              child: Text(
                                onCooldown
                                    ? 'Nothing yet? Check spam, or resend in ${_formatCooldown(_secondsRemaining)}'
                                    : 'Nothing yet? Check spam.',
                                style: AppTypography.helper.copyWith(
                                  color: AppColors.warningText,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_resendErrorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _resendErrorMessage!,
                          style: AppTypography.helper.copyWith(
                            color: AppColors.errorText,
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      AppButton(
                        label: 'Back to log in',
                        onPressed: _backToLogIn,
                      ),
                      const SizedBox(height: 14),
                      AppButton(
                        label: 'Resend link',
                        variant: AppButtonVariant.outlinedNeutral,
                        loading: _resending,
                        onPressed: onCooldown ? null : _resend,
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
