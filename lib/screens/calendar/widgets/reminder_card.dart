import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/enums.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/event_time.dart';
import '../calendar_styles.dart';

/// Bounds of the reminder amount stepper, per the handoff's
/// `if (s.remValue > 1)` / `if (s.remValue < 60)` guards.
const int kReminderAmountMin = 1;
const int kReminderAmountMax = 60;

/// Shown when the amount box holds something that isn't a usable number.
const kReminderAmountRangeMessage =
    'Enter a reminder amount between $kReminderAmountMin and '
    '$kReminderAmountMax.';

/// Which state the note box under the reminder controls is in. Three visual
/// treatments: grey for [awaitingDateTime], green for [valid], and red
/// shared by [passed] and [amountOutOfRange].
enum ReminderNoteState {
  /// No date or time picked yet, so there is nothing to validate against.
  awaitingDateTime,

  /// The reminder will fire in the future.
  valid,

  /// The reminder would fire in the past, so it can never be delivered.
  passed,

  /// The amount box is empty, or holds a number outside 1–60.
  amountOutOfRange,
}

/// The reminder block on Add Event: an enable toggle, and — once on — the
/// amount stepper, the unit chips and a note box explaining the current
/// state.
///
/// The amount can be stepped or typed. Validation is *live*, and for the
/// stepper and the unit chips it refuses invalid input rather than accepting
/// it and complaining later — the handoff is explicit about this: "an
/// invalid value is rejected, not accepted-then-warned". **Typed input is
/// the deliberate exception**: refusing keystrokes would fight the typist
/// (typing "30" passes through "3"), so a typed value is accepted, shown in
/// red on the note box, and blocks Save instead. Out-of-range or empty text
/// is clamped back to a usable value when the field loses focus, so nothing
/// unusable can persist.
class ReminderCard extends StatefulWidget {
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

  /// Reports the amount on every change: the parsed value while it is a
  /// whole number inside 1–60, or **null** while the box is empty or out of
  /// range, so the form knows the reminder is incomplete and can hold Save.
  final ValueChanged<int?> onAmountChanged;
  final ValueChanged<ReminderUnit> onUnitChanged;
  final VoidCallback onToggleUnits;

  /// Called with the message to show when a change is refused because its
  /// lead time has already passed.
  final ValueChanged<String> onRejected;

  @override
  State<ReminderCard> createState() => _ReminderCardState();
}

class _ReminderCardState extends State<ReminderCard> {
  late final TextEditingController _amountController =
      TextEditingController(text: '${widget.amount}');
  late final FocusNode _amountFocus = FocusNode()
    ..addListener(_onFocusChanged);

  @override
  void didUpdateWidget(ReminderCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Mirror a change made elsewhere (the stepper, or a reset) into the box
    // — but never while the box already reads as that number, which would
    // move the caret mid-typing.
    if (widget.amount != oldWidget.amount &&
        _parsed != widget.amount) {
      _amountController.text = '${widget.amount}';
    }
  }

  @override
  void dispose() {
    _amountFocus.dispose();
    _amountController.dispose();
    super.dispose();
  }

  /// The box's contents as an int, or null when empty or unparseable.
  int? get _parsed => int.tryParse(_amountController.text.trim());

  /// Whether the box currently holds a whole number inside 1–60.
  bool get _amountUsable {
    final value = _parsed;
    return value != null &&
        value >= kReminderAmountMin &&
        value <= kReminderAmountMax;
  }

  /// The amount this card should validate and describe: what the box holds
  /// while that is usable, otherwise the last value committed upward.
  ///
  /// Reading the box rather than `widget.amount` keeps the note box and the
  /// stepper correct in the same frame the student types, instead of waiting
  /// for the parent to echo the value back.
  int get _effectiveAmount => _amountUsable ? _parsed! : widget.amount;

  /// Whether a reminder [candidateAmount] [candidateUnit] ahead would
  /// already have fired.
  bool _passed(int candidateAmount, ReminderUnit candidateUnit) =>
      reminderLeadPassed(
        date: widget.date,
        time: widget.time,
        amount: candidateAmount,
        unit: candidateUnit,
        now: widget.now,
      );

  ReminderNoteState get _noteState {
    // An unusable amount outranks everything else: there is no lead time to
    // check until the box holds a number.
    if (!_amountUsable) return ReminderNoteState.amountOutOfRange;
    if (widget.date == null || widget.time == null) {
      return ReminderNoteState.awaitingDateTime;
    }
    return _passed(_effectiveAmount, widget.unit)
        ? ReminderNoteState.passed
        : ReminderNoteState.valid;
  }

  /// Applies a candidate amount/unit from the stepper or a unit chip, or
  /// rejects it when its lead time has already passed.
  void _apply(int candidateAmount, ReminderUnit candidateUnit) {
    if (_passed(candidateAmount, candidateUnit)) {
      widget.onRejected(
        formatReminderPassedMessage(candidateAmount, candidateUnit),
      );
      return;
    }
    if (candidateAmount != widget.amount) {
      // Keep the box in step with a stepped value even when the parent
      // rebuilds with the same `amount` it already had.
      _amountController.text = '$candidateAmount';
      widget.onAmountChanged(candidateAmount);
    }
    if (candidateUnit != widget.unit) widget.onUnitChanged(candidateUnit);
  }

  /// Every keystroke reports upward: the parsed value when it is usable, or
  /// null to tell the form the reminder is incomplete and Save must wait.
  void _onAmountTyped(String _) {
    setState(() {});
    widget.onAmountChanged(_amountUsable ? _parsed : null);
  }

  /// On losing focus, snap an unusable box back to something usable: empty
  /// reverts to the last committed amount, anything out of range clamps to
  /// the nearer bound.
  void _onFocusChanged() {
    if (_amountFocus.hasFocus || _amountUsable) return;
    final value = _parsed;
    final int settled;
    if (value == null) {
      settled = widget.amount;
    } else {
      settled = value < kReminderAmountMin
          ? kReminderAmountMin
          : kReminderAmountMax;
    }
    _amountController.text = '$settled';
    setState(() {});
    widget.onAmountChanged(settled);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled;
    final amount = _effectiveAmount;
    final unit = widget.unit;
    final unitsOpen = widget.unitsOpen;

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
          _ToggleRow(enabled: enabled, onToggled: widget.onToggled),
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
                    controller: _amountController,
                    focusNode: _amountFocus,
                    hasError: _noteState == ReminderNoteState.passed ||
                        _noteState == ReminderNoteState.amountOutOfRange,
                    onTyped: _onAmountTyped,
                    // The box can hold an unusable value mid-typing, so the
                    // stepper steps from the last committed amount.
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
                    onTap: widget.onToggleUnits,
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

/// − value + , where the value is also a numeric text field.
///
/// Bounded by [kReminderAmountMin]/[kReminderAmountMax]: the buttons stop at
/// the bounds, and the field refuses anything but two digits, so the worst a
/// student can type is a number the note box then explains.
class _AmountStepper extends StatelessWidget {
  const _AmountStepper({
    required this.controller,
    required this.focusNode,
    required this.hasError,
    required this.onTyped,
    required this.onDecrement,
    required this.onIncrement,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool hasError;
  final ValueChanged<String> onTyped;

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
            child: TextField(
              key: const ValueKey('reminder-amount'),
              controller: controller,
              focusNode: focusNode,
              onChanged: onTyped,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: false,
                signed: false,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                // 60 is the ceiling, so two digits is all that can be valid.
                LengthLimitingTextInputFormatter(2),
              ],
              textAlign: TextAlign.center,
              style: CalendarText.reminderValue,
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                hintText: '$kReminderAmountMin',
                hintStyle: CalendarText.reminderValueHint,
              ),
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
      ReminderNoteState.amountOutOfRange => (
        AppColors.errorBannerBackground,
        AppColors.errorBannerBody,
        Icons.error_outline,
        kReminderAmountRangeMessage,
      ),
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
