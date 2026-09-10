import 'package:flutter/material.dart';

/// The Tadarab color palette, lifted from the Phase 0 (Auth) and Phase 1
/// (Home & Courses) design handoffs (docs/mockups/android-study-app-redesign).
/// Every screen in the app should build on these tokens rather than
/// hardcoding hex values, so a future palette change happens in one place.
class AppColors {
  AppColors._();

  // Brand.
  /// Primary navy — headline text, primary buttons, focused/filled field borders.
  static const Color navy = Color(0xFF0B0F5B);

  /// Darker navy used for the hard-offset shadow under navy buttons.
  static const Color navyShadow = Color(0xFF070A3E);

  /// Brand red — links, the Forgot Password primary action, error accents.
  static const Color red = Color(0xFFE31B23);

  /// Darker red used for the hard-offset shadow under red buttons.
  static const Color redShadow = Color(0xFFA8141B);

  // Neutrals (navy tinted, per the design system).
  /// Page background.
  static const Color background = Color(0xFFF0F1F7);

  /// Default (unfocused, empty, non-error) field border.
  static const Color borderDefault = Color(0xFFE2E6F5);

  /// Placeholder text / inactive icon color inside fields.
  static const Color placeholder = Color(0xFF9AA0C4);

  /// Secondary body text (subtitles, helper text).
  static const Color textSecondary = Color(0xFF7A80A6);

  /// Muted text/icons on a disabled control (e.g. loading state).
  static const Color disabledMuted = Color(0xFF5B618F);

  /// Shadow tint under a disabled/loading button.
  static const Color disabledShadow = Color(0xFF474C74);

  /// Background for disabled fields and skeleton-like surfaces.
  static const Color surfaceMuted = Color(0xFFF7F8FD);

  /// Background for the neutral circular back-button chip.
  static const Color chipBackground = Color(0xFFF1F3FA);

  /// Faint text on a disabled/loading screen (e.g. "Create an account" link).
  static const Color textOnDisabled = Color(0xFFC9CEE8);

  // Success (valid email format, strong password, matched confirm-password).
  static const Color success = Color(0xFF16A34A);
  static const Color successDark = Color(0xFF15803D);
  static const Color successBackground = Color(0xFFF4FCF7);
  static const Color successBackgroundStrong = Color(0xFFE6F7EC);

  // Error (invalid field, wrong credentials, email already registered).
  static const Color error = Color(0xFFE31B23);
  static const Color errorBackground = Color(0xFFFFF7F7);
  static const Color errorBannerBackground = Color(0xFFFFE9EA);
  static const Color errorBannerBorder = Color(0xFFF6C4C7);
  static const Color errorBannerHeading = Color(0xFF8F0C13);
  static const Color errorBannerBody = Color(0xFFA8141B);
  static const Color errorText = Color(0xFFC31018);

  // Warning (resend-link cooldown chip).
  static const Color warningBackground = Color(0xFFFFF3DC);
  static const Color warningText = Color(0xFF8A5A06);

  // Password strength bar — "Weak" reuses [error]/[errorText] and "Strong"
  // reuses [success]/[successDark]; "Medium" has no source frame in the
  // mockup, so this sits between them in the same warm/cool progression.
  static const Color strengthMedium = Color(0xFFE8A33D);
  static const Color strengthMediumText = Color(0xFFB5720A);
  static const Color strengthTrackEmpty = Color(0xFFEEF0FF);

  // Home & Courses (Phase 1 handoff).
  /// Home's page background — slightly lighter than the auth screens' [background].
  static const Color homeBackground = Color(0xFFF7F8FD);

  /// The dot inside the points badge in the Home greeting.
  static const Color pointsBadgeDot = Color(0xFFF5A524);

  /// Card corner radius used throughout Home (course cards, progress card, etc).
  static const Color cardTint = Color(0xFFEEF0FF);
}

/// Parses a "#RRGGBB" or "#AARRGGBB" hex string (as stored on Course/
/// CalendarEvent) into a [Color]. Falls back to [AppColors.navy] for a
/// malformed value rather than throwing, since this only ever feeds decor.
Color parseHexColor(String hex) {
  var value = hex.trim();
  if (value.startsWith('#')) value = value.substring(1);
  if (value.length == 6) value = 'FF$value';
  final parsed = int.tryParse(value, radix: 16);
  return parsed == null ? AppColors.navy : Color(parsed);
}
