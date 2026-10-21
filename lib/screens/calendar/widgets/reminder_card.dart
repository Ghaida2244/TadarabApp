import 'package:flutter/material.dart';

import '../../../models/enums.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/event_time.dart';
import '../calendar_styles.dart';

/// Bounds of the reminder amount stepper, per the handoff's
/// `if (s.remValue > 1)` / `if (s.remValue < 60)` guards.
const int kReminderAmountMin = 1;
const int kReminderAmountMax = 60;

/// Which of the three states the note box under the reminder controls is in.
enum ReminderNoteState {
  /// No date or time picked yet, so there is nothing to validate against.
  awaitingDateTime,

  /// The reminder will fire in the future.
  valid,

  /// The reminder would fire in the past, so it can never be delivered.
  passed,
}

/// The reminder block on Add Event: an enable toggle, and — once on — the
/// amount stepper, the unit chips and a note box explaining the current
/// state.
///
/// Validation is *live* and refuses invalid input rather than accepting it
/// and complaining later: a unit whose lead time has already passed is
/// greyed out and ignores taps, and the stepper won't commit a value that
/// would put the reminder in the past. The handoff is explicit about this —
/// "an invalid value is rejected, not accepted-then-warned".
class ReminderCard extends StatelessWidget {
  const ReminderCard({
    super.key,
    required this.enabled,
    required this.amount,
    required this.unit,
    required this.unitsOpen,
    required this.date,
    required this.time,
    required this.now,
    required this.onToggled,
    required this.onAmountChanged,
    required this.onUnitChanged,
    required this.onToggleUnits,
    required this.onRejected,
  });

  /// Whether the reminder toggle is on.
  final bool enabled;

  /// Current lead-time amount, always within [kReminderAmountMin]..[kReminderAmountMax].
  final int amount;

  /// Current lead-time unit.
  final ReminderUnit unit;

  /// Whether the inline unit chip row is expanded.
  final bool unitsOpen;

  /// The event's chosen date and time, used to validate the lead time.
  /// Either may still be null while the form is being filled in.
  final DateTime? date;
  final TimeOfDay? time;

  /// "Now", injected so tests are deterministic.
  final DateTime now;

  final ValueChanged<bool> onToggled;
  final ValueChanged<int> onAmountChanged;
  final ValueChanged<ReminderUnit> onUnitChanged;
  final VoidCallback onToggleUnits;

  /// Called with the message to show when a change is refused because its
  /// lead time has already passed.
  final ValueChanged<String> onRejected;

  /// Whether a reminder [candidateAmount] [candidateUnit] ahead would
  /// already have fired.
  bool _passed(int candidateAmount, ReminderUnit candidateUnit) =>
      reminderLeadPassed(
        date: date,
        time: time,
        amount: candidateAmount,
        unit: candidateUnit,
        now: now,
      );

  ReminderNoteState get _noteState {
    if (date == null || time == null) return ReminderNoteState.awaitingDateTime;
    return _passed(amount, unit)
        ? ReminderNoteState.passed
        : ReminderNoteState.valid;
  }

  /// Applies a candidate amount/unit, or rejects it when its lead time has
  /// already passed.
  void _apply(int candidateAmount, ReminderUnit candidateUnit) {
    if (_passed(candidateAmount, candidateUnit)) {
      onRejected(
        formatReminderPassedMessage(candidateAmount, candidateUnit),
      );
      return;
    }
    if (candidateAmount != amount) onAmountChanged(candidateAmount);
    if (candidateUnit != unit) onUnitChanged(candidateUnit);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          const BoxShadow(color: AppColors.cardTint, spreadRadius: 2),
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.06),
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ToggleRow(enabled: enabled, onToggled: onToggled),
          if (enabled) ...[
            const SizedBox(height: 14),
            Text(
              'Set when you want to be notified before this event.',
              style: CalendarText.reminderHelper,
            ),
            const SizedBox(height: 11),
            Row(
              children: [
                Expanded(
                  child: _AmountStepper(
                    amount: amount,
                    hasError: _noteState == ReminderNoteState.passed,
                    onDecrement: amount > kReminderAmountMin
                        ? () => _apply(amount - 1, unit)
                        : null,
                    onIncrement: amount < kReminderAmountMax
                        ? () => _apply(amount + 1, unit)
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 118,
                  child: _UnitButton(
                    label: formatReminderUnitLabel(amount, unit),
                    open: unitsOpen,
                    onTap: onToggleUnits,
                  ),
                ),
              ],
            ),
            if (unitsOpen) ...[
              const SizedBox(height: 11),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  for (final candidate in ReminderUnit.values)
                    _UnitChip(
                      label: formatReminderUnitLabel(amount, candidate),
                      selected: candidate == unit,
                      // A unit that would put the reminder in the past is
                      // shown dimmed and refuses the tap.
                      blocked: _passed(amount, candidate),
                      onTap: () => _apply(amount, candidate),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 11),
            _NoteBox(state: _noteState, amount: amount, unit: unit),
          ],
        ],
      ),
    );
  }
}

/// The bell, the label and the custom pill switch.
class _ToggleRow extends StatelessWidget {
  const _ToggleRow({required this.enabled, required this.onToggled});

  final bool enabled;
  final ValueChanged<bool> onToggled;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: enabled,
      label: 'Enable reminder',
      child: GestureDetector(
        key: const ValueKey('reminder-toggle'),
        onTap: () => onToggled(!enabled),
        behavior: HitTestBehavior.opaque,
        child: Row(
          children: [
            Icon(
              Icons.notifications_none,
              size: 19,
              color: enabled ? AppColors.navy : AppColors.placeholder,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Enable reminder',
                style: CalendarText.reminderTitle,
              ),
            ),
            // A hand-built switch: Material's Switch has its own metrics
            // and can't be made 52x30 with a 24px knob.
            Container(
              width: 52,
              height: 30,
              padding: const EdgeInsets.all(3),
              alignment:
                  enabled ? Alignment.centerRight : Alignment.centerLeft,
              decoration: BoxDecoration(
                color: enabled ? AppColors.navy : AppColors.borderLight,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.navy.withValues(alpha: 0.3),
                      offset: const Offset(0, 1),
                      blurRadius: 3,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// − value + , bounded by [kReminderAmountMin]/[kReminderAmountMax].
class _AmountStepper extends StatelessWidget {
  const _AmountStepper({
    required this.amount,
    required this.hasError,
    required this.onDecrement,
    required this.onIncrement,
  });

  final int amount;
  final bool hasError;

  /// Null at the corresponding bound, which greys that button out.
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasError ? AppColors.red : AppColors.borderLight,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          _StepperButton(
            glyph: '−',
            semanticLabel: 'Fewer',
            onTap: onDecrement,
            buttonKey: const ValueKey('reminder-decrement'),
          ),
          Expanded(
            child: Text(
              '$amount',
              key: const ValueKey('reminder-amount'),
              textAlign: TextAlign.center,
              style: CalendarText.reminderValue,
            ),
          ),
          _StepperButton(
            glyph: '+',
            semanticLabel: 'More',
            onTap: onIncrement,
            buttonKey: const ValueKey('reminder-increment'),
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.glyph,
    required this.semanticLabel,
    required this.onTap,
    required this.buttonKey,
  });

  final String glyph;
  final String semanticLabel;
  final VoidCallback? onTap;
  final Key buttonKey;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        key: buttonKey,
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: disabled ? AppColors.cardTint : AppColors.navy,
            shape: BoxShape.circle,
          ),
          child: Text(
            glyph,
            style: CalendarText.reminderStepper(
              disabled ? AppColors.textOnDisabled : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

/// The 118px button that expands the unit chip row.
class _UnitButton extends StatelessWidget {
  const _UnitButton({
    required this.label,
    required this.open,
    required this.onTap,
  });

  final String label;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Reminder unit',
      child: GestureDetector(
        key: const ValueKey('reminder-unit'),
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: open ? AppColors.navy : AppColors.borderLight,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(label, style: CalendarText.reminderUnit),
              ),
              Icon(
                open ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                size: 20,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One unit in the inline row. A [blocked] chip is dimmed and inert.
class _UnitChip extends StatelessWidget {
  const _UnitChip({
    required this.label,
    required this.selected,
    required this.blocked,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool blocked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color background = selected
        ? AppColors.navy
        : (blocked ? AppColors.surfaceMuted : Colors.white);
    final Color ink = selected
        ? Colors.white
        : (blocked ? AppColors.textOnDisabled : AppColors.disabledMuted);
    final Color edge = selected
        ? AppColors.navy
        : (blocked ? AppColors.cardTint : AppColors.borderDefault);

    return Semantics(
      button: true,
      enabled: !blocked,
      selected: selected,
      child: GestureDetector(
        key: ValueKey('reminder-unit-chip-$label'),
        onTap: blocked ? null : onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: edge, width: 2),
          ),
          child: Text(label, style: CalendarText.reminderUnitChip(ink)),
        ),
      ),
    );
  }
}

/// The grey / green / red note under the reminder controls.
class _NoteBox extends StatelessWidget {
  const _NoteBox({
    required this.state,
    required this.amount,
    required this.unit,
  });

  final ReminderNoteState state;
  final int amount;
  final ReminderUnit unit;

  @override
  Widget build(BuildContext context) {
    final (background, ink, icon, message) = switch (state) {
      ReminderNoteState.awaitingDateTime => (
        AppColors.surfaceMuted,
        AppColors.textSecondary,
        Icons.check,
        'Pick a date and time and we will check this reminder against them.',
      ),
      ReminderNoteState.valid => (
        AppColors.successBackgroundStrong,
        AppColors.successDark,
        Icons.check,
        formatReminderConfirmMessage(amount, unit),
      ),
      ReminderNoteState.passed => (
        AppColors.errorBannerBackground,
        AppColors.errorBannerBody,
        Icons.error_outline,
        formatReminderPassedMessage(amount, unit),
      ),
    };

    return Container(
      key: const ValueKey('reminder-note'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 15, color: ink),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: CalendarText.reminderNote(ink)),
          ),
        ],
      ),
    );
  }
}
