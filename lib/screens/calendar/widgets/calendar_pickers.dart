import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

/// Corner radius shared by both pickers, matching the Calendar's own
/// dialogs (the delete confirmation and the colour picker).
const double kPickerCornerRadius = 26;

/// The standard Android date and time pickers, restyled to the Calendar's
/// look: white surfaces, Nunito throughout, navy selection, and the
/// design's rounded corners.
///
/// A team decision recorded in CLAUDE.md: the unified Calendar design uses
/// the platform's own date and time inputs, so the hand-built
/// `EventDatePickerSheet` / `EventTimePickerSheet` (written to match SRS
/// Figures 98–99) were removed in favour of Flutter's pickers. This
/// deliberately departs from those two figures.
///
/// The **layouts stay standard** — the month grid and the clock dial are
/// Android's, which is the point of using them. Only the palette, the font
/// and the shapes change.
///
/// Everything here is a local [Theme] wrapper rather than a change to the
/// shared `AppTheme`: that file is frozen after Phase B, and no other
/// screen in the app opens a Material picker. Material 3's defaults are
/// what produced the lavender surfaces — they come from `surfaceContainerHigh`
/// (the dialog), `primaryContainer` (the selected day) and
/// `secondaryContainer` (the time picker's hour/minute fields and AM/PM
/// toggle), so each is overridden explicitly below rather than relying on
/// the colour scheme alone.

/// Nunito at the weight and size the pickers need.
TextStyle _nunito(double size, FontWeight weight, {Color? color}) => TextStyle(
  fontFamily: 'Nunito',
  fontSize: size,
  fontWeight: weight,
  color: color,
);

/// Navy when selected, navy-on-white otherwise — the pattern both pickers
/// use for day and year cells.
WidgetStateProperty<Color?> _selectionForeground() {
  return WidgetStateProperty.resolveWith((states) {
    if (states.contains(WidgetState.disabled)) return AppColors.textOnDisabled;
    if (states.contains(WidgetState.selected)) return Colors.white;
    return AppColors.navy;
  });
}

WidgetStateProperty<Color?> _selectionBackground() {
  return WidgetStateProperty.resolveWith((states) {
    if (states.contains(WidgetState.selected)) return AppColors.navy;
    return Colors.transparent;
  });
}

/// The muted "dismiss" action, matching the delete dialog's "Keep it".
ButtonStyle _cancelButtonStyle() => TextButton.styleFrom(
  foregroundColor: AppColors.textSecondary,
  textStyle: _nunito(14, FontWeight.w900),
);

/// The red "confirm" action, matching the delete dialog's "Delete event".
ButtonStyle _confirmButtonStyle() => TextButton.styleFrom(
  foregroundColor: AppColors.red,
  textStyle: _nunito(15, FontWeight.w900),
);

ThemeData _pickerTheme(BuildContext context) {
  final base = Theme.of(context);
  final shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(kPickerCornerRadius),
  );

  return base.copyWith(
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.navy,
      onPrimary: Colors.white,
      surface: Colors.white,
      onSurface: AppColors.navy,
      // The containers M3 reaches for by default; pinned so nothing
      // lavender leaks through a slot not named explicitly below.
      surfaceContainerHigh: Colors.white,
      primaryContainer: AppColors.navy,
      onPrimaryContainer: Colors.white,
      secondaryContainer: AppColors.cardTint,
      onSecondaryContainer: AppColors.navy,
      onSurfaceVariant: AppColors.textSecondary,
      outline: AppColors.borderLight,
    ),

    datePickerTheme: DatePickerThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shadowColor: AppColors.navy.withValues(alpha: 0.12),
      shape: shape,
      // A white header with navy ink, rather than M3's filled primary bar.
      headerBackgroundColor: Colors.white,
      headerForegroundColor: AppColors.navy,
      headerHeadlineStyle: _nunito(26, FontWeight.w900),
      headerHelpStyle: _nunito(12, FontWeight.w900),
      weekdayStyle: _nunito(13, FontWeight.w900, color: AppColors.placeholder),
      dayStyle: _nunito(14, FontWeight.w800),
      dayForegroundColor: _selectionForeground(),
      dayBackgroundColor: _selectionBackground(),
      dayShape: const WidgetStatePropertyAll(CircleBorder()),
      // Today is outlined in red when it isn't the selection, the same
      // treatment the month grid gives it.
      todayForegroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? Colors.white
            : AppColors.red,
      ),
      todayBackgroundColor: _selectionBackground(),
      todayBorder: const BorderSide(color: AppColors.red, width: 1.5),
      yearStyle: _nunito(14, FontWeight.w800),
      yearForegroundColor: _selectionForeground(),
      yearBackgroundColor: _selectionBackground(),
      dividerColor: AppColors.borderLight,
      subHeaderForegroundColor: AppColors.navy,
      toggleButtonTextStyle: _nunito(14, FontWeight.w900),
      cancelButtonStyle: _cancelButtonStyle(),
      confirmButtonStyle: _confirmButtonStyle(),
    ),

    timePickerTheme: TimePickerThemeData(
      backgroundColor: Colors.white,
      shape: shape,
      elevation: 3,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      helpTextStyle: _nunito(12, FontWeight.w900, color: AppColors.placeholder),
      // The dial keeps its standard layout; only its colours change.
      dialBackgroundColor: AppColors.surfaceMuted,
      dialHandColor: AppColors.navy,
      dialTextStyle: _nunito(15, FontWeight.w800),
      dialTextColor: WidgetStateColor.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? Colors.white
            : AppColors.navy,
      ),
      hourMinuteShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      hourMinuteColor: WidgetStateColor.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.navy
            : AppColors.surfaceMuted,
      ),
      hourMinuteTextColor: WidgetStateColor.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? Colors.white
            : AppColors.navy,
      ),
      hourMinuteTextStyle: _nunito(34, FontWeight.w900),
      timeSelectorSeparatorColor: const WidgetStatePropertyAll(
        AppColors.navy,
      ),
      timeSelectorSeparatorTextStyle: WidgetStatePropertyAll(
        _nunito(34, FontWeight.w900),
      ),
      dayPeriodShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      dayPeriodBorderSide: const BorderSide(
        color: AppColors.borderLight,
        width: 1.5,
      ),
      dayPeriodColor: WidgetStateColor.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.navy
            : Colors.white,
      ),
      dayPeriodTextColor: WidgetStateColor.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? Colors.white
            : AppColors.textSecondary,
      ),
      dayPeriodTextStyle: _nunito(14, FontWeight.w900),
      entryModeIconColor: AppColors.textSecondary,
      cancelButtonStyle: _cancelButtonStyle(),
      confirmButtonStyle: _confirmButtonStyle(),
    ),

    // The input-mode text fields both pickers can switch to.
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceMuted,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.borderLight, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.borderLight, width: 2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.navy, width: 2),
      ),
      labelStyle: _nunito(12, FontWeight.w900, color: AppColors.placeholder),
      hintStyle: _nunito(15, FontWeight.w800, color: AppColors.placeholder),
    ),

    // A backstop for any picker text not covered by a named slot above —
    // the year-picker list, the "Select date" input field, and so on.
    textTheme: base.textTheme.apply(fontFamily: 'Nunito'),

    // Covers the pickers' icon buttons (the keyboard/calendar entry-mode
    // toggle and the month paging arrows).
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: AppColors.navy),
    ),
    textButtonTheme: TextButtonThemeData(style: _confirmButtonStyle()),
  );
}

/// Opens the restyled date picker, resolving to the chosen day or null if
/// the student cancels.
///
/// [firstDate] reaches five years back on purpose: past dates stay
/// selectable, which is the team's standing decision — a calendar is as
/// much a record of what happened as a plan. (Figure 98 greys past days
/// out; we don't.)
Future<DateTime?> pickEventDate({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime now,
}) {
  return showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: DateTime(now.year - 5),
    lastDate: DateTime(now.year + 5, 12, 31),
    builder: (context, child) =>
        Theme(data: _pickerTheme(context), child: child!),
  );
}

/// Opens the restyled time picker, resolving to the chosen time or null if
/// the student cancels.
Future<TimeOfDay?> pickEventTime({
  required BuildContext context,
  required TimeOfDay? initialTime,
}) {
  return showTimePicker(
    context: context,
    initialTime: initialTime ?? const TimeOfDay(hour: 9, minute: 0),
    builder: (context, child) =>
        Theme(data: _pickerTheme(context), child: child!),
  );
}
