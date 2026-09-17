import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../utils/event_time.dart';
import '../../../widgets/app_button.dart';

/// Fill behind the selected day, sampled from SRS Figure 98. A neutral grey
/// with no matching [AppColors] token; kept local rather than added to the
/// shared palette, which is frozen after Phase B.
const _selectedDayFill = Color(0xFFC7CBD2);

/// Opens the Add Event date picker (SRS Figure 98) and resolves to the
/// tapped day, or null if the student cancels or dismisses it.
///
/// Custom rather than Material's `showDatePicker`, so it matches the app's
/// navy/red look: a mini month grid with a red-outlined today marker and a
/// grey selected day. Tapping a day selects it and closes the sheet — there
/// is no separate confirm step in the figure.
///
/// Past days are selectable and the previous-month arrow stays enabled. This
/// deliberately departs from Figure 98, which greys both out: the team
/// decided a calendar should also be able to record past events.
Future<DateTime?> showEventDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime today,
  DateTime? selectedDate,
}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => EventDatePickerSheet(
      initialMonth: initialDate,
      today: today,
      selectedDate: selectedDate,
    ),
  );
}

/// The sheet behind [showEventDatePicker]. Public so it can be widget-tested
/// directly.
class EventDatePickerSheet extends StatefulWidget {
  const EventDatePickerSheet({
    super.key,
    required this.initialMonth,
    required this.today,
    this.selectedDate,
  });

  /// Any date inside the month shown first.
  final DateTime initialMonth;

  /// Drives the red outline, injected so tests are deterministic.
  final DateTime today;

  /// The day already chosen on the form, highlighted grey, if any.
  final DateTime? selectedDate;

  @override
  State<EventDatePickerSheet> createState() => _EventDatePickerSheetState();
}

class _EventDatePickerSheetState extends State<EventDatePickerSheet> {
  late DateTime _month = firstOfMonth(widget.initialMonth);

  @override
  Widget build(BuildContext context) {
    final cells = monthGridCells(_month);
    final padded = [
      ...cells,
      ...List<DateTime?>.filled((7 - cells.length % 7) % 7, null),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _ArrowButton(
                  icon: Icons.chevron_left,
                  semanticLabel: 'Previous month',
                  onTap: () =>
                      setState(() => _month = addMonths(_month, -1)),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      formatMonthTitle(_month),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: AppColors.navy,
                      ),
                    ),
                  ),
                ),
                _ArrowButton(
                  icon: Icons.chevron_right,
                  semanticLabel: 'Next month',
                  onTap: () => setState(() => _month = addMonths(_month, 1)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                for (final label in kWeekdayHeadersShort)
                  Expanded(
                    child: Center(
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.placeholder,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            for (var i = 0; i < padded.length; i += 7)
              Row(
                children: [
                  for (final day in padded.sublist(i, i + 7))
                    Expanded(
                      child: day == null
                          ? const SizedBox(height: 46)
                          : _DayButton(
                              day: day,
                              isToday: isSameDay(day, widget.today),
                              isSelected:
                                  widget.selectedDate != null &&
                                  isSameDay(day, widget.selectedDate!),
                              onTap: () => Navigator.of(context).pop(day),
                            ),
                    ),
                ],
              ),
            const SizedBox(height: 14),
            AppButton(
              label: 'Cancel',
              variant: AppButtonVariant.outlinedNeutral,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.surfaceMuted,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: AppColors.navy),
        ),
      ),
    );
  }
}

class _DayButton extends StatelessWidget {
  const _DayButton({
    required this.day,
    required this.isToday,
    required this.isSelected,
    required this.onTap,
  });

  final DateTime day;
  final bool isToday;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: ValueKey('picker-day-${day.day}'),
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 46,
        child: Center(
          child: Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected ? _selectedDayFill : null,
              borderRadius: BorderRadius.circular(10),
              border: isToday
                  ? Border.all(color: AppColors.red, width: 1.5)
                  : null,
            ),
            child: Text(
              '${day.day}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: isToday ? AppColors.red : AppColors.navy,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
