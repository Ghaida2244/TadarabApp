import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Text styles used only by the Profile section's screens.
///
/// Local rather than added to `AppTypography` for the same reason the
/// Calendar's `calendar_styles.dart` is: that file is shared and frozen
/// after Phase B, and a change to it needs review from all four members.
/// Every colour here still comes from the shared [AppColors] (rank colours
/// excepted — they live in `lib/utils/rank.dart` as rank data), and every
/// style names Nunito explicitly.
///
/// Sizes, weights and letter-spacings come from
/// `docs/mockups/design-handoff_profile/.../Tadarab Phase 3b - Profile.dc.html`.
class ProfileText {
  const ProfileText._();

  static TextStyle _nunito(
    double size,
    FontWeight weight, {
    Color? color,
    double? letterSpacing,
    double? height,
  }) => TextStyle(
    fontFamily: 'Nunito',
    fontSize: size,
    fontWeight: weight,
    color: color ?? AppColors.navy,
    letterSpacing: letterSpacing,
    height: height,
  );

  // ── Headers ──────────────────────────────────────────────────────────

  /// The student's name under the avatar — 22px, -0.01em.
  static TextStyle get profileName =>
      _nunito(22, FontWeight.w900, color: Colors.white, letterSpacing: -0.22);

  /// "Ranks" / "Edit Profile" / "Study Reminder" / a document title — 23px.
  static TextStyle get screenTitle =>
      _nunito(23, FontWeight.w900, color: Colors.white, letterSpacing: -0.46);

  /// "Student Summary" / "Settings" / "About" — 18px.
  static TextStyle get sectionTitle => _nunito(18, FontWeight.w900);

  // ── Student summary ──────────────────────────────────────────────────

  /// "TOTAL POINTS" / "RANK" above a summary figure — 11px, 0.03em.
  static TextStyle get summaryLabel => _nunito(
    11,
    FontWeight.w900,
    color: AppColors.placeholder,
    letterSpacing: 0.33,
  );

  /// The points figure — 22px.
  static TextStyle get summaryPoints =>
      _nunito(22, FontWeight.w900, height: 1);

  /// The rank's short name in the summary card — 18px.
  static TextStyle get summaryRank =>
      _nunito(18, FontWeight.w900, height: 1.2);

  // ── Rank progress card ───────────────────────────────────────────────

  /// The current rank's full name — 15px.
  static TextStyle get rankName => _nunito(15, FontWeight.w900);

  /// The red "View Ranks" link — 13px.
  static TextStyle get viewRanks =>
      _nunito(13, FontWeight.w900, color: AppColors.red);

  /// "550 pts to Advanced" — 12px.
  static TextStyle get rankToNext =>
      _nunito(12, FontWeight.w900, color: AppColors.disabledMuted);

  /// "1,450 / 1,799 pts" — 12px.
  static TextStyle get rankProgress =>
      _nunito(12, FontWeight.w800, color: AppColors.textSecondary);

  // ── Settings / About rows ────────────────────────────────────────────

  /// A row's title — 15px.
  static TextStyle get rowTitle => _nunito(15, FontWeight.w900);

  /// The Study Reminder row's summary line, green when on and grey when
  /// off — 12px.
  static TextStyle rowSummary(Color color) =>
      _nunito(12, FontWeight.w800, color: color);

  /// The red Log Out button's label — 15px.
  static TextStyle get logOut =>
      _nunito(15, FontWeight.w900, color: AppColors.red);

  // ── Ranks screen ─────────────────────────────────────────────────────

  /// A rank row's name, dimmed for a rank not yet reached — 15px.
  static TextStyle rankRowName(Color color) =>
      _nunito(15, FontWeight.w900, color: color);

  /// "0 – 99 pts" — 12px.
  static TextStyle get rankRange =>
      _nunito(12, FontWeight.w800, color: AppColors.textSecondary);

  /// "3 / 10" — 11px.
  static TextStyle get rankTier =>
      _nunito(11, FontWeight.w900, color: AppColors.placeholder);

  /// "COMPLETED" / "IN PROGRESS" / "LOCKED" — 11px, 0.03em.
  static TextStyle rankStatus(Color color) =>
      _nunito(11, FontWeight.w900, color: color, letterSpacing: 0.33);

  /// The percentage beside the status — 11px.
  static TextStyle get rankPercent =>
      _nunito(11, FontWeight.w900, color: AppColors.placeholder);

  /// "200 pts until next rank", on the current rank's row only — 12px.
  static TextStyle get rankUntilNext =>
      _nunito(12, FontWeight.w800, color: AppColors.disabledMuted);

  /// The "CURRENT" pill. Hidden by default, per the design's own prop —
  /// kept so turning it on is a one-line change.
  static TextStyle get rankBadge => _nunito(
    10,
    FontWeight.w900,
    color: Colors.white,
    letterSpacing: 0.4,
  );

  // ── Edit Profile ─────────────────────────────────────────────────────

  /// "NAME" / "EMAIL" — 12px, 0.06em.
  static TextStyle get fieldLabel => _nunito(
    12,
    FontWeight.w900,
    color: AppColors.placeholder,
    letterSpacing: 0.72,
  );

  /// Field contents — 16px.
  static TextStyle fieldInput(Color color) =>
      _nunito(16, FontWeight.w800, color: color);

  /// The note under a field — 12px.
  static TextStyle fieldNote(Color color) =>
      _nunito(12, FontWeight.w800, color: color, height: 1.5);

  // ── Study Reminder ───────────────────────────────────────────────────

  /// "Enable Reminder" — 16px.
  static TextStyle get reminderTitle => _nunito(16, FontWeight.w900);

  /// "Get a daily nudge to study" — 12px.
  static TextStyle get reminderSubtitle =>
      _nunito(12, FontWeight.w800, color: AppColors.textSecondary);

  /// "Reminder Time" — 14px.
  static TextStyle get reminderSectionTitle => _nunito(14, FontWeight.w900);

  /// The chosen time, or "--:-- --" when unset — 18px.
  static TextStyle reminderTime(Color color) =>
      _nunito(18, FontWeight.w900, color: color);

  /// The helper under the time field — 12px.
  static TextStyle reminderHelper(Color color) =>
      _nunito(12, FontWeight.w800, color: color, height: 1.5);

  // ── Save buttons and documents ───────────────────────────────────────

  /// Any "Save Changes" button — 16px.
  static TextStyle get save =>
      _nunito(16, FontWeight.w900, color: Colors.white);

  /// A document block's heading — 15px.
  static TextStyle get docHeading => _nunito(15, FontWeight.w900);

  /// A document block's body — 13px, line-height 1.65.
  static TextStyle get docBody => _nunito(
    13,
    FontWeight.w800,
    color: AppColors.disabledMuted,
    height: 1.65,
  );

  /// The coloured lead-in on a Learning Guide line — 13px.
  static TextStyle docLead(Color color) =>
      _nunito(13, FontWeight.w900, color: color);

  // ── Learning Guide (lively) ──────────────────────────────────────────

  /// "HOW TO EARN POINTS" — 12px, 0.06em.
  static TextStyle get guideEyebrow => _nunito(
    12,
    FontWeight.w900,
    color: AppColors.placeholder,
    letterSpacing: 0.72,
  );

  /// The big "+4" on a points tile — 26px, -0.03em.
  static TextStyle guideTileValue(Color color) =>
      _nunito(26, FontWeight.w900, color: color, letterSpacing: -0.78, height: 1);

  /// The "pts" beside it — 12px.
  static TextStyle guideTileUnit(Color color) =>
      _nunito(12, FontWeight.w900, color: color);

  /// A tile's label ("Quiz") — 14px.
  static TextStyle get guideTileLabel => _nunito(14, FontWeight.w900);

  /// A tile's sub-label ("per correct answer") — 10px.
  static TextStyle get guideTileUnitLabel => _nunito(
    10,
    FontWeight.w800,
    color: AppColors.disabledMuted,
    height: 1.4,
  );

  /// A guide card's heading — 15px.
  static TextStyle get guideHeading => _nunito(15, FontWeight.w900);

  /// A guide card's body — 12px.
  static TextStyle get guideBody => _nunito(
    12,
    FontWeight.w800,
    color: AppColors.disabledMuted,
    height: 1.5,
  );

  /// A scope chip ("LEARNING MODE") — 10px, 0.03em.
  static TextStyle get guideScope =>
      _nunito(10, FontWeight.w900, letterSpacing: 0.3);
}

/// Colours the Profile section needs that the shared [AppColors] lacks.
/// Kept local for the same frozen-shared-file reason as [ProfileText].
class ProfileColors {
  const ProfileColors._();

  /// The Log Out button's tinted fill and border (`#FFF2F3` / `#FFD3D5`).
  static const Color logOutFill = Color(0xFFFFF2F3);
  static const Color logOutBorder = Color(0xFFFFD3D5);

  /// The muted ink the design uses for a locked or not-yet-reached row
  /// (`#7A80A6` exists as textSecondary; this is the dimmer `#3A4070` used
  /// for the current rank's status line).
  static const Color statusCurrent = Color(0xFF3A4070);
}
