import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../utils/event_time.dart';
import '../../../widgets/app_button.dart';

/// Opens the Add Event time picker (SRS Figure 99) and resolves to the
/// confirmed time, or null if the student closes it with the ✕.
///
/// Custom rather than Material's `showTimePicker` dial: a live "12:00 PM"
/// preview, an Hour grid (1–12), a Minute grid in 5-minute steps, an AM/PM
/// toggle, and a red Confirm button. Nothing is returned until Confirm, so
/// tapping around the grids never changes the form by itself.
Future<TimeOfDay?> showEventTimePicker({
  required BuildContext context,
  TimeOfDay? initialTime,
}) {
  return showModalBottomSheet<TimeOfDay>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => EventTimePickerSheet(initialTime: initialTime),
  );
}

/// The sheet behind [showEventTimePicker]. Public so it can be widget-tested
/// directly.
class EventTimePickerSheet extends StatefulWidget {
  const EventTimePickerSheet({super.key, this.initialTime});

  /// Pre-selects this time; defaults to 12:00 PM, as Figure 99 shows.
  final TimeOfDay? initialTime;

  @override
  State<EventTimePickerSheet> createState() => _EventTimePickerSheetState();
}

class _EventTimePickerSheetState extends State<EventTimePickerSheet> {
  static const _hours = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];
  static const _minutes = [0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55];

  late int _hour12;
  late int _minute;
  late bool _isPm;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialTime ?? const TimeOfDay(hour: 12, minute: 0);
    _hour12 = initial.hour % 12 == 0 ? 12 : initial.hour % 12;
    // The grid only offers 5-minute steps, so an off-step time (only
    // possible from data written elsewhere) snaps down to a real button
    // rather than leaving nothing highlighted.
    _minute = initial.minute - initial.minute % 5;
    _isPm = initial.hour >= 12;
  }

  TimeOfDay get _time =>
      timeOfDayFrom12Hour(hour12: _hour12, minute: _minute, isPm: _isPm)!;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Select Time',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.navy,
                  ),
                ),
                Semantics(
                  button: true,
                  label: 'Close',
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: AppColors.surfaceMuted,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Center(
              child: Text(
                formatEventTimeForDisplay(_time),
                key: const ValueKey('time-preview'),
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: AppColors.navy,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const _GridLabel('Hour'),
            _OptionGrid(
              children: [
                for (final hour in _hours)
                  _OptionButton(
                    key: ValueKey('hour-$hour'),
                    label: '$hour',
                    selected: hour == _hour12,
                    onTap: () => setState(() => _hour12 = hour),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const _GridLabel('Minute'),
            _OptionGrid(
              children: [
                for (final minute in _minutes)
                  _OptionButton(
                    key: ValueKey('minute-$minute'),
                    label: minute.toString().padLeft(2, '0'),
                    selected: minute == _minute,
                    onTap: () => setState(() => _minute = minute),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const _GridLabel('Period'),
            Row(
              children: [
                Expanded(
                  child: _OptionButton(
                    key: const ValueKey('period-am'),
                    label: 'AM',
                    selected: !_isPm,
                    height: 44,
                    onTap: () => setState(() => _isPm = false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _OptionButton(
                    key: const ValueKey('period-pm'),
                    label: 'PM',
                    selected: _isPm,
                    height: 44,
                    onTap: () => setState(() => _isPm = true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            AppButton(
              label: '✓ Confirm',
              variant: AppButtonVariant.accent,
              onPressed: () => Navigator.of(context).pop(_time),
            ),
          ],
        ),
      ),
    );
  }
}

class _GridLabel extends StatelessWidget {
  const _GridLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

/// A six-column grid of [_OptionButton]s, as both Hour and Minute use.
class _OptionGrid extends StatelessWidget {
  const _OptionGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < children.length; i += 6) ...[
          if (i > 0) const SizedBox(height: 8),
          Row(
            children: [
              for (var j = i; j < i + 6; j++) ...[
                if (j > i) const SizedBox(width: 8),
                Expanded(child: children[j]),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _OptionButton extends StatelessWidget {
  const _OptionButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.height = 40,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.navy : AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(12),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: AppColors.navyShadow,
                      offset: Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: selected ? Colors.white : AppColors.navy,
            ),
          ),
        ),
      ),
    );
  }
}
