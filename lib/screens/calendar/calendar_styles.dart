import 'dart:math';

import 'package:flutter/material.dart';

import '../../services/courses_service.dart'
    show kCoursePresetColors, kDefaultCourseColor;
import '../../theme/app_theme.dart';

/// Text styles and the two palette values used only by the Calendar
/// feature's screens.
///
/// Deliberately local rather than added to `AppTypography`/`AppColors`:
/// those are shared files, frozen after Phase B, and a change to either
/// needs review from all four members. Every colour here still comes from
/// the shared [AppColors], and every style sets Nunito explicitly, so the
/// Calendar stays inside the app's design system without editing it.
///
/// Sizes, weights and letter-spacings are taken from
/// `docs/mockups/design-handoff_Calendar/.../Tadarab Phase 3 - Calendar.dc.html`.
class CalendarText {
  const CalendarText._();

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

  // ── Navy headers (Calendar tab + Add Event) ──────────────────────────

  /// "Calendar" / "Add Event" — 24px, w900, -0.02em.
  static TextStyle get headerTitle => _nunito(
    24,
    FontWeight.w900,
    color: Colors.white,
    letterSpacing: -0.48,
  );

  /// The red "Add Event" pill's label — 14px.
  static TextStyle get headerAction =>
      _nunito(14, FontWeight.w900, color: Colors.white);

  /// "March 2026" between the month arrows, and the year in year view.
  static TextStyle get headerMonth =>
      _nunito(17, FontWeight.w900, color: Colors.white);

  /// The "Back to today" pill — 12px.
  static TextStyle get backToToday =>
      _nunito(12, FontWeight.w900, color: Colors.white);

  // ── Month grid ───────────────────────────────────────────────────────

  /// "Sun".."Sat" column headers — 14px, w900, 0.03em.
  static TextStyle get weekday => _nunito(
    14,
    FontWeight.w900,
    color: AppColors.placeholder,
    letterSpacing: 0.42,
  );

  /// A day number in the month grid — 18px, w800.
  static TextStyle dayNumber(Color color) =>
      _nunito(18, FontWeight.w800, color: color);

  /// The "+2" shown when a day holds more events than fit as dots.
  static TextStyle get dayOverflow =>
      _nunito(9, FontWeight.w900, color: AppColors.textSecondary);

  /// The line under the grid when the viewed month holds no events. Not in
  /// the handoff (its empty-state branch renders nothing) — kept because a
  /// blank month otherwise reads as a loading failure.
  static TextStyle get monthEmpty => _nunito(
    13,
    FontWeight.w800,
    color: AppColors.textSecondary,
    height: 1.5,
  );

  // ── Year view ────────────────────────────────────────────────────────

  /// "Jan".."Dec" on a mini-month card — 13px.
  static TextStyle miniMonth(Color color) =>
      _nunito(13, FontWeight.w900, color: color);

  /// A day number inside a mini-month — 9px.
  static TextStyle miniDay(Color color) =>
      _nunito(9, FontWeight.w900, color: color);

  // ── Day details sheet ────────────────────────────────────────────────

  /// "March 14, 2026" — 19px, w900, -0.01em.
  static TextStyle get sheetDate =>
      _nunito(19, FontWeight.w900, letterSpacing: -0.19);

  /// "2 events" under the date — 12px.
  static TextStyle get sheetCount =>
      _nunito(12, FontWeight.w800, color: AppColors.textSecondary);

  /// An event's name in the sheet — 15px, line-height 1.3.
  static TextStyle get eventName =>
      _nunito(15, FontWeight.w900, height: 1.3);

  /// The linked course's name, drawn in that event's own colour.
  static TextStyle eventCourse(Color color) =>
      _nunito(12, FontWeight.w900, color: color);

  /// "12:00 PM · reminder 1 day before" — 12px.
  static TextStyle get eventMeta =>
      _nunito(12, FontWeight.w800, color: AppColors.textSecondary);

  /// "Finished" — the small grey divider label between today's not-yet-
  /// started and already-started events.
  static TextStyle get sheetSectionLabel => _nunito(
    11,
    FontWeight.w800,
    color: AppColors.textSecondary,
    letterSpacing: 0.3,
  );

  /// "No events on this day" heading in the sheet's dashed empty state.
  static TextStyle get sheetEmptyTitle => _nunito(15, FontWeight.w900);

  /// Its supporting line.
  static TextStyle get sheetEmptyBody => _nunito(
    12,
    FontWeight.w800,
    color: AppColors.textSecondary,
    height: 1.5,
  );

  // ── Delete confirmation ──────────────────────────────────────────────

  /// "Delete this event?" — 19px.
  static TextStyle get dialogTitle => _nunito(19, FontWeight.w900);

  /// Its body — 14px, w700, line-height 1.6.
  static TextStyle get dialogBody => _nunito(
    14,
    FontWeight.w700,
    color: AppColors.textSecondary,
    height: 1.6,
  );

  // ── Add Event form ───────────────────────────────────────────────────

  /// "EVENT NAME" / "DATE" — 12px, w900, 0.06em, all-caps in the source.
  static TextStyle get fieldLabel => _nunito(
    12,
    FontWeight.w900,
    color: AppColors.placeholder,
    letterSpacing: 0.72,
  );

  /// The "· OPTIONAL" half of the COURSE label, a step lighter.
  static TextStyle get fieldLabelOptional => _nunito(
    12,
    FontWeight.w900,
    color: AppColors.textOnDisabled,
    letterSpacing: 0.72,
  );

  /// Typed or picked text inside a field — 15px, w800.
  static TextStyle fieldInput(Color color) =>
      _nunito(15, FontWeight.w800, color: color);

  /// A row in the inline course dropdown — 14px.
  static TextStyle get courseOption => _nunito(14, FontWeight.w900);

  /// The "no courses yet" line in that dropdown. Not in the handoff, whose
  /// course list is never empty.
  static TextStyle get courseEmpty => _nunito(
    12,
    FontWeight.w800,
    color: AppColors.textSecondary,
    height: 1.5,
  );

  /// The linked-course chip's name — 14px.
  static TextStyle get chipName => _nunito(14, FontWeight.w900);

  /// "Event will use this course color" — 12px.
  static TextStyle get chipCaption =>
      _nunito(12, FontWeight.w800, color: AppColors.textSecondary);

  /// "Enable reminder" — 15px.
  static TextStyle get reminderTitle => _nunito(15, FontWeight.w900);

  /// "Set when you want to be notified before this event." — 12px.
  static TextStyle get reminderHelper => _nunito(
    12,
    FontWeight.w800,
    color: AppColors.textSecondary,
    height: 1.5,
  );

  /// The stepper's current amount, typed or stepped — 17px.
  static TextStyle get reminderValue => _nunito(17, FontWeight.w900);

  /// The amount field's hint, shown only while the box is empty.
  static TextStyle get reminderValueHint =>
      _nunito(17, FontWeight.w900, color: AppColors.textOnDisabled);

  /// The "−" / "+" glyphs — 22px.
  static TextStyle reminderStepper(Color color) =>
      _nunito(22, FontWeight.w900, color: color);

  /// The unit button's label ("Days") — 14px.
  static TextStyle get reminderUnit => _nunito(14, FontWeight.w900);

  /// A unit chip in the inline row — 12px.
  static TextStyle reminderUnitChip(Color color) =>
      _nunito(12, FontWeight.w900, color: color);

  /// The three-state note under the reminder controls — 12px.
  static TextStyle reminderNote(Color color) =>
      _nunito(12, FontWeight.w800, color: color, height: 1.5);

  /// The pinned Save button's label — 16px.
  static TextStyle get save =>
      _nunito(16, FontWeight.w900, color: Colors.white);

  /// "Add an event name to continue." under a disabled Save — 11px.
  static TextStyle get saveReason =>
      _nunito(11, FontWeight.w800, color: AppColors.errorBannerBody);
}

/// Calendar-only colour values with no equivalent in the shared
/// [AppColors]. Kept here for the same frozen-shared-file reason as
/// [CalendarText]; everything else the Calendar draws comes from
/// [AppColors].
class CalendarColors {
  const CalendarColors._();

  /// Background of the selected row in the inline course dropdown
  /// (`#F4F6FF` in the handoff) — one step lighter than
  /// [AppColors.cardTint].
  static const Color selectedRow = Color(0xFFF4F6FF);
}

/// The pool the Add Event colour swatches are drawn from, in the handoff's
/// order.
///
/// The four offered swatches are this pool minus every hue already taken by
/// one of the student's courses, so a manually-coloured event can never be
/// mistaken for a course-linked one. Event data, not a theme role — which
/// is why it lives in the feature rather than in `AppColors`.
const List<String> kEventSwatchPool = [
  '#16A34A',
  '#2563EB',
  '#F5A524',
  '#E31B23',
  '#7C3AED',
  '#0D9488',
  '#DB2777',
  '#EA580C',
  '#0EA5E9',
  '#65A30D',
  '#C026D3',
  '#B45309',
  '#4F46E5',
  '#BE123C',
  '#0F766E',
  '#0B0F5B',
  '#0891B2', // cyan — appended; the rest of the pool keeps its order.
];

/// Formats [color] as the `"#RRGGBB"` string events are stored with.
///
/// Alpha is dropped deliberately: `CalendarEvent.color` is a 6-digit hex and
/// every swatch in [kEventSwatchPool] is fully opaque, so carrying an alpha
/// channel through would produce a value `parseHexColor` reads back as a
/// different colour. Always returns 7 characters, upper-case.
String hexFromColor(Color color) {
  final rgb = color.toARGB32() & 0xFFFFFF;
  return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

/// The colour Add Event preselects when it opens: [kDefaultCourseColor]
/// (green), unless a course already uses it, then the medium amber, then
/// the next free colour in [kEventSwatchPool]'s own order; if every pool
/// colour is somehow already claimed by a course, the pool's first colour
/// anyway — the row is never actually left with no selection.
String defaultEventColor(Iterable<String> courseColors) {
  const green = kDefaultCourseColor;
  const amber = '#F5A524';
  final taken = courseColors.map((c) => c.toUpperCase()).toSet();
  if (!taken.contains(green)) return green;
  if (!taken.contains(amber)) return amber;
  for (final hex in kEventSwatchPool) {
    if (!taken.contains(hex.toUpperCase())) return hex;
  }
  return kEventSwatchPool.first;
}

/// The colour Add Event preselects when it opens: one entry from
/// [kEventSwatchPool], chosen at random, that is none of:
/// [kCoursePresetColors] (Add course's own 5 presets — a standalone event
/// should never look like it's secretly a course), [courseColors] (any of
/// the student's own courses), or [standaloneColors] (the student's saved
/// quick-colours, which are by definition colours already used by one of
/// her standalone events).
///
/// Unrelated to [defaultEventColor] — that one stays exactly as-is for Add
/// course, which still wants its own green→amber→first-free-preset order,
/// not a random pick, and never touches [kEventSwatchPool] beyond its own
/// fallback walk.
///
/// If every pool colour is excluded, the exclusions are relaxed one at a
/// time rather than giving up: first allowing a colour already used by a
/// standalone event, then also allowing a preset, and if that's still
/// somehow empty, [kEventSwatchPool]'s first colour regardless.
///
/// [random] is injectable so a test can pass a seeded [Random] for a
/// deterministic pick; defaults to a fresh [Random] otherwise.
String randomEventColor({
  required Iterable<String> courseColors,
  required Iterable<String> standaloneColors,
  Random? random,
}) {
  final presets = kCoursePresetColors.map((c) => c.toUpperCase()).toSet();
  final courseTaken = courseColors.map((c) => c.toUpperCase()).toSet();
  final standaloneTaken = standaloneColors.map((c) => c.toUpperCase()).toSet();

  List<String> freeFrom(Set<String> excluded) => [
    for (final hex in kEventSwatchPool)
      if (!excluded.contains(hex.toUpperCase())) hex,
  ];

  var candidates = freeFrom({...presets, ...courseTaken, ...standaloneTaken});
  if (candidates.isEmpty) candidates = freeFrom({...presets, ...courseTaken});
  if (candidates.isEmpty) candidates = freeFrom(courseTaken);
  if (candidates.isEmpty) return kEventSwatchPool.first;

  final rng = random ?? Random();
  return candidates[rng.nextInt(candidates.length)];
}

/// One tile in Add Event's colour row.
class EventColorTile {
  const EventColorTile(this.hex, {this.removable = false});

  final String hex;

  /// True only for a tile drawn from the student's saved list — never the
  /// default-when-empty tile or the extra selected-colour tile, and never
  /// the "+" tile (which isn't represented here at all; the caller adds it
  /// separately). Only a removable tile shows the "×" badge.
  final bool removable;

  @override
  bool operator ==(Object other) =>
      other is EventColorTile && other.hex == hex && other.removable == removable;

  @override
  int get hashCode => Object.hash(hex, removable);

  @override
  String toString() => 'EventColorTile($hex, removable: $removable)';
}

/// The colour tiles Add Event's colour row offers, in display order — the
/// dashed/rainbow "+" tile is added separately by the caller, after these:
///
/// 1. [savedColors] (already capped at 5 and ordered most-recent-first by
///    the caller), each marked [EventColorTile.removable] so its tile shows
///    the "×" badge.
/// 2. One extra, non-removable tile for [selectedColor] — the screen's
///    current selection, whether that's the one-time random default
///    ([randomEventColor]), a saved colour already covered by 1 (a no-op
///    here, since it's already in the list), or a fresh pick from the full
///    colour-picker dialog. This is also what makes the row never just the
///    "+" with nothing selected: [selectedColor] is only null for the
///    brief window before the screen's one-time load resolves.
///
/// A colour any of [courseColors] currently uses is dropped from
/// [savedColors] — the student already gets that colour by picking the
/// course itself — but never from [selectedColor]: the random default
/// already excludes course colours by construction, and a colour picked
/// from the dialog is never filtered, same as before. Dropping a saved
/// colour this way never changes the saved list itself — the filter only
/// applies to what's displayed.
List<EventColorTile> eventColorTiles({
  required List<String> savedColors,
  required Iterable<String> courseColors,
  String? selectedColor,
}) {
  final takenByCourse = courseColors.map((c) => c.toUpperCase()).toSet();
  final tiles = <EventColorTile>[];
  final seen = <String>{};

  void addTile(String hex, {bool removable = false}) {
    if (seen.add(hex.toUpperCase())) {
      tiles.add(EventColorTile(hex, removable: removable));
    }
  }

  for (final hex in savedColors) {
    if (!takenByCourse.contains(hex.toUpperCase())) addTile(hex, removable: true);
  }

  if (selectedColor != null) addTile(selectedColor);

  return tiles;
}
