import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

/// The standard Android date and time pickers, themed to the app's
/// navy/red palette.
///
/// A team decision recorded in CLAUDE.md: the unified Calendar design uses
/// the platform's own date and time inputs, so the hand-built
/// `EventDatePickerSheet` / `EventTimePickerSheet` (written to match SRS
/// Figures 98–99) were removed in favour of Flutter's pickers. This
/// deliberately departs from those two figures.
///
/// The palette is applied as a local [Theme] wrapper rather than by
/// changing the shared `AppTheme` — that file is frozen after Phase B, and
/// no other screen in the app opens a Material picker.
ThemeData _pickerTheme(BuildContext context) {
  final base = Theme.of(context);
  return base.copyWith(
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.navy,
      onPrimary: Colors.white,
      surface: Colors.white,
      onSurface: AppColors.navy,
    ),
    // Cancel/OK read as the design's red actions.
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.red,
        textStyle: const TextStyle(
          fontFamily: 'Nunito',
          fontWeight: FontWeight.w900,
          fontSize: 15,
        ),
      ),
    ),
  );
}

/// Opens the themed date picker, resolving to the chosen day or null if the
/// student cancels.
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

/// Opens the themed time picker, resolving to the chosen time or null if
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
