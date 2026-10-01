import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Text styles built on Nunito (the design handoff's font), at the weights
/// and sizes actually used across the mockup frames. Named by role rather
/// than size, so screens describe intent ("fieldLabel") not pixels.
///
/// Nunito is bundled as a font asset (see pubspec `fonts:`), so it renders
/// offline and on first launch — it is *not* fetched at runtime.
class AppTypography {
  AppTypography._();

  static TextStyle _nunito(
    double size,
    FontWeight weight, {
    Color? color,
    double? letterSpacing,
    double? height,
  }) {
    return TextStyle(
      fontFamily: 'Nunito',
      fontSize: size,
      fontWeight: weight,
      color: color ?? AppColors.navy,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  /// The 38px promo headline (design-doc cover frame only; not used in-app).
  static TextStyle get display =>
      _nunito(38, FontWeight.w900, letterSpacing: -0.02 * 38, height: 1.1);

  /// Screen titles, e.g. "Create Account", "Welcome back", "Check your email".
  static TextStyle get screenTitle =>
      _nunito(28, FontWeight.w900, letterSpacing: -0.02 * 28);

  /// Slightly smaller screen title variant (Login, Check your email).
  static TextStyle get screenTitleCompact =>
      _nunito(26, FontWeight.w900, letterSpacing: -0.02 * 26);

  /// The Welcome screen's tagline ("Study smarter, not longer").
  static TextStyle get promoTitle =>
      _nunito(24, FontWeight.w900, letterSpacing: -0.01 * 24);

  /// Primary button label.
  static TextStyle get button =>
      _nunito(16, FontWeight.w900, color: Colors.white);

  /// Secondary (outlined) button label.
  static TextStyle get buttonSecondary => _nunito(15, FontWeight.w900);

  /// Field input text / placeholder text.
  static TextStyle get fieldInput =>
      _nunito(15, FontWeight.w700, color: AppColors.navy);

  /// Filled password dots.
  static TextStyle get fieldPassword => _nunito(
    17,
    FontWeight.w900,
    color: AppColors.navy,
    letterSpacing: 0.18 * 17,
  );

  /// Subtitle / supporting body text under a screen title.
  static TextStyle get subtitle =>
      _nunito(14, FontWeight.w700, color: AppColors.textSecondary, height: 1.5);

  /// Field labels ("Email", "Password").
  static TextStyle get fieldLabel => _nunito(12, FontWeight.w900);

  /// Inline helper/error text under a field.
  static TextStyle get helper =>
      _nunito(12, FontWeight.w800, color: AppColors.textSecondary);

  /// Small links and footer text ("Create an account", "Forgot password?").
  static TextStyle get link =>
      _nunito(13, FontWeight.w900, color: AppColors.red);

  /// Small body text paired with [link] ("New to Tadarab?").
  static TextStyle get footerBody =>
      _nunito(13, FontWeight.w800, color: AppColors.textSecondary);

  /// Password-strength bar label ("Weak"/"Medium"/"Strong").
  static TextStyle get strengthLabel => _nunito(11, FontWeight.w900);

  /// Error/warning banner heading.
  static TextStyle get bannerHeading =>
      _nunito(14, FontWeight.w900, color: AppColors.errorBannerHeading);

  /// Error/warning banner body.
  static TextStyle get bannerBody => _nunito(
    12,
    FontWeight.w800,
    color: AppColors.errorBannerBody,
    height: 1.5,
  );

  /// The small "TADARAB · PHASE 0" eyebrow label (design-doc cover only).
  static TextStyle get eyebrow => _nunito(
    13,
    FontWeight.w900,
    color: AppColors.red,
    letterSpacing: 0.08 * 13,
  );

  // Quiz (Phase 2 handoff).

  /// A navy-header screen title, e.g. "Quiz sessions" / "Quiz setup" — white
  /// on the navy header bar.
  static TextStyle get quizHeaderTitle => _nunito(
    24,
    FontWeight.w900,
    color: Colors.white,
    letterSpacing: -0.02 * 24,
  );

  /// Small meta text on a navy header (session count, mistake count).
  static TextStyle get quizHeaderMeta => _nunito(
    13,
    FontWeight.w900,
    color: Colors.white.withValues(alpha: 0.65),
  );

  /// Section eyebrow labels, e.g. "MATERIALS", "DIFFICULTY", "IN PROGRESS".
  static TextStyle get quizEyebrow => _nunito(
    12,
    FontWeight.w900,
    color: AppColors.placeholder,
    letterSpacing: 0.06 * 12,
  );

  /// A session/material card's title line.
  static TextStyle get quizCardTitle =>
      _nunito(17, FontWeight.w900, height: 1.25);

  /// A pill/badge label, e.g. "LEARNING" / "EXAM".
  static TextStyle get quizBadge =>
      _nunito(10, FontWeight.w900, letterSpacing: 0.04 * 10);

  /// A status label paired with a colored dot ("Completed" / "In progress").
  static TextStyle get quizStatus => _nunito(12, FontWeight.w900);

  /// The quiz question text itself.
  static TextStyle get quizQuestion =>
      _nunito(21, FontWeight.w900, height: 1.35);

  /// An answer option's text (weight varies selected/revealed — pass
  /// [weight] explicitly).
  static TextStyle quizOption(FontWeight weight, {Color? color}) =>
      _nunito(15, weight, color: color ?? AppColors.navy, height: 1.4);

  /// An option's lettered key circle (A/B/C/D).
  static TextStyle get quizOptionKey => _nunito(12, FontWeight.w900);

  /// "EXPLANATION" / "FIND IT IN YOUR MATERIAL" panel labels.
  static TextStyle quizPanelLabel({Color? color}) => _nunito(
    11,
    FontWeight.w900,
    color: color ?? AppColors.placeholder,
    letterSpacing: 0.06 * 11,
  );

  /// The explanation panel's body text.
  static TextStyle get quizPanelBody =>
      _nunito(14, FontWeight.w800, height: 1.6);

  /// The source-location strip's value text ("Lecture 1 · Slide 8").
  static TextStyle get quizSourceValue =>
      _nunito(14, FontWeight.w900, color: Colors.white);

  /// Performance Summary's screen title.
  static TextStyle get quizSummaryTitle => _nunito(
    26,
    FontWeight.w900,
    color: Colors.white,
    letterSpacing: -0.02 * 26,
    height: 1.15,
  );

  /// The big correct/wrong count numbers.
  static TextStyle quizResultCount(Color color) =>
      _nunito(34, FontWeight.w900, color: color, height: 1);

  /// "CORRECT" / "WRONG" labels under the counts.
  static TextStyle get quizResultCountLabel => _nunito(
    11,
    FontWeight.w900,
    color: AppColors.textSecondary,
    letterSpacing: 0.06 * 11,
  );

  /// The motivational result line.
  static TextStyle quizResultLine(Color color) =>
      _nunito(14, FontWeight.w900, color: color, height: 1.5);

  /// "Points earned" label / value in the summary's points strip.
  static TextStyle get quizPointsLabel =>
      _nunito(14, FontWeight.w900, color: AppColors.warningText);
  static TextStyle get quizPointsValue =>
      _nunito(24, FontWeight.w900, color: AppColors.warningText);

  /// A dialog's title / body copy (limit dialog, delete/exit confirmations).
  static TextStyle get quizDialogTitle => _nunito(19, FontWeight.w900);
  static TextStyle get quizDialogBody => _nunito(
    14,
    FontWeight.w700,
    color: AppColors.textSecondary,
    height: 1.6,
  );

  /// The empty-state title/body on Quiz sessions.
  static TextStyle get quizEmptyTitle => _nunito(20, FontWeight.w900);
  static TextStyle get quizEmptyBody => _nunito(
    13,
    FontWeight.w700,
    color: AppColors.textSecondary,
    height: 1.55,
  );
}
