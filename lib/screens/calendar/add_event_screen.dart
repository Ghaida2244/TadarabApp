import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/calendar_event.dart';
import '../../models/course.dart';
import '../../models/enums.dart';
import '../../services/calendar_service.dart';
import '../../services/home_data_service.dart';
import '../../services/reminder_scheduler.dart';
import '../../theme/app_theme.dart';
import '../../utils/event_time.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_error_banner.dart';
import '../../widgets/dashed_border.dart';
import 'widgets/event_date_picker_sheet.dart';
import 'widgets/event_time_picker_sheet.dart';

/// Maximum length of an event name — `eventName` is VARCHAR(100) in the SRS
/// Attributes Dictionary Table.
const int kEventNameMaxLength = 100;

/// Shown under the reminder row when the chosen lead time has already
/// passed, so the reminder could never fire.
const kReminderPassedMessage =
    'This reminder time has already passed. Choose a shorter reminder or turn it off.';

/// Shown after saving when the student declined notification permission.
const kReminderPermissionDeniedMessage =
    "Event saved, but its reminder couldn't be set because notifications are "
    'turned off for Tadarab.';

/// Shown after saving when the platform refused to schedule the reminder.
const kReminderNotScheduledMessage =
    "Event saved, but its reminder couldn't be set.";

/// The four preset event colors offered when no course is selected
/// (05_add_event_no_course.png). Green is first and pre-selected, and is
/// the same value as CalendarEvent's default color.
const List<String> kEventColorPresets = [
  '#10B981',
  '#4F7DF3',
  '#F0A93B',
  '#E31B23',
];

/// The Add Event form. Writes straight to Firestore via [CalendarService]
/// and, when a reminder is enabled, schedules the local notification.
///
/// Pops `true` once an event has been saved, so the Calendar screen knows
/// to tell Home to re-read its Upcoming section.
class AddEventScreen extends StatefulWidget {
  const AddEventScreen({
    super.key,
    required this.uid,
    required this.calendarService,
    required this.homeDataService,
    this.reminderScheduler,
    this.initialDate,
    this.now,
  });

  final String uid;
  final CalendarService calendarService;
  final HomeDataService homeDataService;

  /// Overridable for tests; defaults to the real notification-backed one.
  final ReminderScheduler? reminderScheduler;

  /// The month the Calendar was showing, used to seed the date picker so
  /// adding an event to a browsed month doesn't jump back to today.
  final DateTime? initialDate;

  /// Overridable for tests, so the date picker's bounds are deterministic.
  final DateTime? now;

  @override
  State<AddEventScreen> createState() => _AddEventScreenState();
}

class _AddEventScreenState extends State<AddEventScreen> {
  final _nameController = TextEditingController();
  final _reminderAmountController = TextEditingController(text: '1');

  late final ReminderScheduler _scheduler =
      widget.reminderScheduler ?? ReminderScheduler();
  late final Future<List<Course>> _courses = widget.homeDataService
      .fetchCourses(widget.uid);

  Course? _selectedCourse;
  String _selectedColor = kEventColorPresets.first;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _reminderEnabled = false;
  ReminderUnit _reminderUnit = ReminderUnit.days;

  bool _saving = false;
  String? _errorMessage;
  String? _nameError;
  String? _dateError;
  String? _timeError;
  String? _reminderError;

  DateTime get _now => widget.now ?? DateTime.now();

  /// A course's color wins over the presets — the chip in the mockup says
  /// the event "will use this course color", so the picker is replaced
  /// rather than merely overridden.
  String get _effectiveColor => _selectedCourse?.color ?? _selectedColor;

  @override
  void dispose() {
    _nameController.dispose();
    _reminderAmountController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    // Past dates stay selectable (the picker applies no lower bound): a
    // calendar is as much a record of what happened as a plan.
    final picked = await showEventDatePicker(
      context: context,
      initialDate: _selectedDate ?? widget.initialDate ?? _now,
      today: _now,
      selectedDate: _selectedDate,
    );
    if (picked == null) return;
    setState(() {
      _selectedDate = picked;
      _dateError = null;
      _reminderError = null;
    });
  }

  Future<void> _pickTime() async {
    final picked = await showEventTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked == null) return;
    setState(() {
      _selectedTime = picked;
      _timeError = null;
      _reminderError = null;
    });
  }

  Future<void> _pickCourse(List<Course> courses) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _CoursePickerSheet(
        courses: courses,
        selected: _selectedCourse,
        onSelected: (course) {
          Navigator.of(sheetContext).pop();
          setState(() => _selectedCourse = course);
        },
      ),
    );
  }

  Future<void> _pickReminderUnit() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _ReminderUnitSheet(
        selected: _reminderUnit,
        amount: _reminderAmount,
        onSelected: (unit) {
          Navigator.of(sheetContext).pop();
          setState(() {
            _reminderUnit = unit;
            _reminderError = null;
          });
        },
      ),
    );
  }

  /// The reminder amount as typed, falling back to 1 for an empty or
  /// non-numeric box so a half-typed value can never be saved as 0.
  int get _reminderAmount {
    final parsed = int.tryParse(_reminderAmountController.text.trim());
    if (parsed == null || parsed < 1) return 1;
    return parsed;
  }

  /// A copy of [event] with a new ID and/or the reminder switched off.
  /// Built here rather than as a `copyWith` on [CalendarEvent] because model
  /// classes are shared files, frozen after Phase B. Switching the reminder
  /// off also clears its lead time, matching an event saved with it off.
  CalendarEvent _copyEvent(
    CalendarEvent event, {
    String? eventId,
    bool? reminderEnabled,
  }) {
    final enabled = reminderEnabled ?? event.reminderEnabled;
    return CalendarEvent(
      eventId: eventId ?? event.eventId,
      eventName: event.eventName,
      eventDate: event.eventDate,
      eventTime: event.eventTime,
      reminderEnabled: enabled,
      reminderBefore: enabled ? event.reminderBefore : null,
      reminderUnit: enabled ? event.reminderUnit : null,
      color: event.color,
      email: event.email,
      courseId: event.courseId,
    );
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    setState(() {
      _errorMessage = null;
      _nameError = name.isEmpty ? 'Event name is required' : null;
      _dateError = _selectedDate == null ? 'Pick a date for this event' : null;
      _timeError = _selectedTime == null ? 'Pick a time for this event' : null;
      _reminderError = null;
    });
    if (_nameError != null || _dateError != null || _timeError != null) return;

    final event = CalendarEvent(
      // Replaced by the ID reserved just before saving; the model requires
      // a non-null eventId, and this value is never stored.
      eventId: '',
      eventName: name,
      eventDate: DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
      ),
      eventTime: formatEventTimeForStorage(_selectedTime!),
      reminderEnabled: _reminderEnabled,
      reminderBefore: _reminderEnabled ? _reminderAmount : null,
      reminderUnit: _reminderEnabled ? _reminderUnit : null,
      color: _effectiveColor,
      // Filled in from the signed-in student by CalendarService.addEvent;
      // this screen has no access to the student's email.
      email: '',
      courseId: _selectedCourse?.courseId,
    );

    // A reminder whose fire time has already passed can never be delivered.
    // Say so on the form rather than saving it and silently skipping it, so
    // the student can shorten the lead time or turn the reminder off.
    if (reminderAlreadyPassed(event, _now)) {
      setState(() => _reminderError = kReminderPassedMessage);
      return;
    }

    setState(() => _saving = true);

    // The reminder is set up *before* the event is written, so the one
    // write can store whether it actually exists: reminderEnabled must
    // reflect what's true on the device, not what the student asked for.
    // That needs the document ID up front (it's the notification's handle),
    // hence reserving one first.
    final eventId = widget.calendarService.newEventId(widget.uid);
    final requested = _copyEvent(event, eventId: eventId);

    String? reminderNotice;
    var reminderSet = false;
    if (_reminderEnabled) {
      // Asked before writing, so Android's permission dialog appears over
      // the form the student is looking at rather than after it closes. On
      // Android 13+ a reminder can't be shown at all without it.
      if (!await _scheduler.requestPermission()) {
        reminderNotice = kReminderPermissionDeniedMessage;
      } else if (await _scheduler.scheduleReminder(requested)) {
        reminderSet = true;
      } else {
        reminderNotice = kReminderNotScheduledMessage;
      }
    }

    // A reminder that couldn't be set is stored as off, with no lead time —
    // the same shape as an event saved with the toggle off.
    final toSave = _reminderEnabled && !reminderSet
        ? _copyEvent(requested, reminderEnabled: false)
        : requested;

    try {
      // A reminder problem never fails the save — it's reported below, never
      // skipped silently.
      await widget.calendarService.addEvent(widget.uid, toSave);

      if (!mounted) return;
      // Captured before popping: the message is shown on the Calendar screen
      // underneath, which is where the student lands.
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop(true);
      if (reminderNotice != null) {
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: AppColors.navy,
            content: Text(
              reminderNotice,
              style: AppTypography.button.copyWith(fontSize: 14),
            ),
          ),
        );
      }
    } on CalendarFailure catch (failure) {
      // The event never got written, so its reminder must not fire either.
      if (reminderSet) await _scheduler.cancelReminder(eventId);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errorMessage = failure.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.homeBackground,
      body: Column(
        children: [
          _AddEventHeader(enabled: !_saving),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_errorMessage != null) ...[
                    AppErrorBanner(
                      heading: "Couldn't save your event",
                      body: _errorMessage!,
                    ),
                    const SizedBox(height: 20),
                  ],
                  const _SectionLabel(emoji: '🏷️', text: 'Event Name'),
                  _FieldBox(
                    errorText: _nameError,
                    child: TextField(
                      key: const ValueKey('event-name'),
                      controller: _nameController,
                      enabled: !_saving,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(kEventNameMaxLength),
                      ],
                      style: AppTypography.fieldInput.copyWith(fontSize: 16),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        hintText: 'e.g. Midterm Exam, Assignment 1',
                        hintStyle: AppTypography.fieldInput.copyWith(
                          fontSize: 16,
                          color: AppColors.placeholder,
                        ),
                      ),
                      onChanged: (_) {
                        if (_nameError != null) {
                          setState(() => _nameError = null);
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 18),
                  const _SectionLabel(
                    emoji: '📖',
                    text: 'Course',
                    suffix: '(Optional)',
                  ),
                  FutureBuilder<List<Course>>(
                    future: _courses,
                    builder: (context, snapshot) {
                      final courses = snapshot.data ?? const <Course>[];
                      return _PickerBox(
                        enabled: !_saving,
                        onTap: () => _pickCourse(courses),
                        placeholder: 'No course selected',
                        value: _selectedCourse?.courseName,
                        trailing: const Icon(
                          Icons.keyboard_arrow_down,
                          size: 22,
                          color: AppColors.textSecondary,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  if (_selectedCourse != null)
                    _CourseColorChip(course: _selectedCourse!)
                  else ...[
                    const _SectionLabel(emoji: '🎨', text: 'Event Color'),
                    _ColorPresetRow(
                      selected: _selectedColor,
                      onSelected: (hex) =>
                          setState(() => _selectedColor = hex),
                      onCustom: _pickCustomColor,
                    ),
                  ],
                  const SizedBox(height: 18),
                  const _SectionLabel(emoji: '📅', text: 'Date'),
                  _PickerBox(
                    enabled: !_saving,
                    onTap: _pickDate,
                    placeholder: 'Select a date',
                    value: _selectedDate == null
                        ? null
                        : formatLongDate(_selectedDate!),
                    errorText: _dateError,
                    trailing: const Text('📅', style: TextStyle(fontSize: 18)),
                  ),
                  const SizedBox(height: 18),
                  const _SectionLabel(emoji: '🕐', text: 'Time'),
                  _PickerBox(
                    enabled: !_saving,
                    onTap: _pickTime,
                    placeholder: 'Select a time',
                    value: _selectedTime == null
                        ? null
                        : formatEventTimeForDisplay(_selectedTime!),
                    errorText: _timeError,
                    trailing: const Text('🕐', style: TextStyle(fontSize: 18)),
                  ),
                  const SizedBox(height: 18),
                  _ReminderToggleCard(
                    enabled: _reminderEnabled,
                    onChanged: _onReminderToggled,
                  ),
                  if (_reminderEnabled) ...[
                    const SizedBox(height: 12),
                    _ReminderAmountRow(
                      controller: _reminderAmountController,
                      unitLabel: formatReminderUnitLabel(
                        _reminderAmount,
                        _reminderUnit,
                      ),
                      onUnitTap: _pickReminderUnit,
                      onAmountChanged: () =>
                          setState(() => _reminderError = null),
                      errorText: _reminderError,
                    ),
                  ],
                  const SizedBox(height: 26),
                  AppButton(
                    label: 'Save Event',
                    loading: _saving,
                    loadingLabel: 'Saving…',
                    onPressed: _saving ? null : _save,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onReminderToggled(bool value) {
    setState(() {
      _reminderEnabled = value;
      _reminderError = null;
    });
  }

  Future<void> _pickCustomColor() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _CustomColorSheet(
        selected: _selectedColor,
        onSelected: (hex) {
          Navigator.of(sheetContext).pop();
          setState(() => _selectedColor = hex);
        },
      ),
    );
  }
}

/// Navy header with the circular back chip, matching the Add Event mockup.
class _AddEventHeader extends StatelessWidget {
  const _AddEventHeader({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.navy,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Semantics(
              button: true,
              label: 'Back',
              child: GestureDetector(
                onTap: enabled ? () => Navigator.of(context).pop() : null,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.chevron_left,
                    size: 26,
                    color: Colors.white.withValues(alpha: enabled ? 1 : 0.4),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            const Text(
              'Add Event',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// An emoji + label heading above a field, e.g. "🏷️ Event Name".
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.emoji, required this.text, this.suffix});

  final String emoji;
  final String text;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 7),
          Text(
            text,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: AppColors.navy,
            ),
          ),
          if (suffix != null) ...[
            const SizedBox(width: 7),
            Text(
              suffix!,
              style: AppTypography.subtitle.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The white rounded input box the mockup uses for every field. Separate
/// from [AppTextField] because these have no leading icon and their label
/// sits outside the box as a [_SectionLabel].
class _FieldBox extends StatelessWidget {
  const _FieldBox({required this.child, this.errorText});

  final Widget child;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 60,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: errorText == null
                  ? AppColors.borderLight
                  : AppColors.error,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.navy.withValues(alpha: 0.05),
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: child,
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              errorText!,
              style: AppTypography.helper.copyWith(color: AppColors.errorText),
            ),
          ),
      ],
    );
  }
}

/// A [_FieldBox] that opens a picker instead of accepting typed input.
class _PickerBox extends StatelessWidget {
  const _PickerBox({
    required this.enabled,
    required this.onTap,
    required this.placeholder,
    required this.value,
    this.trailing,
    this.errorText,
  });

  final bool enabled;
  final VoidCallback onTap;
  final String placeholder;
  final String? value;
  final Widget? trailing;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: _FieldBox(
        errorText: errorText,
        child: Row(
          children: [
            Expanded(
              child: Text(
                value ?? placeholder,
                style: AppTypography.fieldInput.copyWith(
                  fontSize: 16,
                  color: value == null
                      ? AppColors.placeholder
                      : AppColors.navy,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

/// The four preset swatches plus the dashed "+" for a custom color.
class _ColorPresetRow extends StatelessWidget {
  const _ColorPresetRow({
    required this.selected,
    required this.onSelected,
    required this.onCustom,
  });

  final String selected;
  final ValueChanged<String> onSelected;
  final VoidCallback onCustom;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final hex in kEventColorPresets) ...[
          Semantics(
            button: true,
            selected: hex == selected,
            label: 'Event color $hex',
            child: GestureDetector(
              onTap: () => onSelected(hex),
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 62,
                height: 62,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: parseHexColor(hex),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: hex == selected
                    ? const Icon(Icons.check, size: 26, color: Colors.white)
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Semantics(
          button: true,
          label: 'Custom event color',
          child: GestureDetector(
            onTap: onCustom,
            behavior: HitTestBehavior.opaque,
            child: DashedRoundedBorder(
              color: AppColors.borderDefault,
              borderRadius: 16,
              child: const SizedBox(
                width: 62,
                height: 62,
                child: Icon(Icons.add, size: 24, color: AppColors.placeholder),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Replaces the preset row once a course is chosen, per the mockup.
class _CourseColorChip extends StatelessWidget {
  const _CourseColorChip({required this.course});

  final Course course;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderLight, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: parseHexColor(course.color),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course.courseName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppColors.navy,
                  ),
                ),
                Text(
                  'Event will use this course color',
                  style: AppTypography.subtitle.copyWith(fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReminderToggleCard extends StatelessWidget {
  const _ReminderToggleCard({required this.enabled, required this.onChanged});

  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderLight, width: 1.5),
      ),
      child: Row(
        children: [
          const Text('🔔', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Enable Reminder',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: AppColors.navy,
              ),
            ),
          ),
          Switch(
            value: enabled,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: AppColors.navy,
          ),
        ],
      ),
    );
  }
}

class _ReminderAmountRow extends StatelessWidget {
  const _ReminderAmountRow({
    required this.controller,
    required this.unitLabel,
    required this.onUnitTap,
    required this.onAmountChanged,
    this.errorText,
  });

  final TextEditingController controller;
  final String unitLabel;
  final VoidCallback onUnitTap;
  final VoidCallback onAmountChanged;

  /// Shown under the row, e.g. when the reminder's lead time has passed.
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return _FieldBox(
      errorText: errorText,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: const ValueKey('reminder-amount'),
              controller: controller,
              keyboardType: TextInputType.number,
              style: AppTypography.fieldInput.copyWith(fontSize: 16),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
              ),
              onChanged: (_) => onAmountChanged(),
            ),
          ),
          Semantics(
            button: true,
            label: 'Reminder unit',
            child: GestureDetector(
              key: const ValueKey('reminder-unit'),
              onTap: onUnitTap,
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  Text(
                    unitLabel,
                    style: AppTypography.fieldInput.copyWith(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Icon(
                    Icons.keyboard_arrow_down,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared chrome for the small option sheets below.
class _OptionSheet extends StatelessWidget {
  const _OptionSheet({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _SheetRow extends StatelessWidget {
  const _SheetRow({
    required this.label,
    required this.selected,
    required this.onTap,
    this.leading,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: selected ? AppColors.cardTint : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.navy : AppColors.borderLight,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            ?leading,
            if (leading != null) const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AppColors.navy,
                ),
              ),
            ),
            if (selected)
              const Icon(Icons.check, size: 20, color: AppColors.navy),
          ],
        ),
      ),
    );
  }
}

class _CoursePickerSheet extends StatelessWidget {
  const _CoursePickerSheet({
    required this.courses,
    required this.selected,
    required this.onSelected,
  });

  final List<Course> courses;
  final Course? selected;
  final ValueChanged<Course?> onSelected;

  @override
  Widget build(BuildContext context) {
    return _OptionSheet(
      title: 'Choose a course',
      children: [
        _SheetRow(
          label: 'No course',
          selected: selected == null,
          onTap: () => onSelected(null),
        ),
        if (courses.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              "You haven't added any courses yet. Events can still be saved without one.",
              style: AppTypography.subtitle,
            ),
          )
        else
          for (final course in courses)
            _SheetRow(
              label: course.courseName,
              selected: course.courseId == selected?.courseId,
              onTap: () => onSelected(course),
              leading: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: parseHexColor(course.color),
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
            ),
      ],
    );
  }
}

class _ReminderUnitSheet extends StatelessWidget {
  const _ReminderUnitSheet({
    required this.selected,
    required this.amount,
    required this.onSelected,
  });

  final ReminderUnit selected;
  final int amount;
  final ValueChanged<ReminderUnit> onSelected;

  @override
  Widget build(BuildContext context) {
    return _OptionSheet(
      title: 'Remind me',
      children: [
        for (final unit in ReminderUnit.values)
          _SheetRow(
            label: formatReminderUnitLabel(amount, unit),
            selected: unit == selected,
            onTap: () => onSelected(unit),
          ),
      ],
    );
  }
}

class _CustomColorSheet extends StatelessWidget {
  const _CustomColorSheet({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  /// A wider palette behind the dashed "+", so "custom" is still a
  /// fixed, on-brand set rather than a free-form colour wheel.
  static const _customColors = [
    '#0B0F5B',
    '#7C3AED',
    '#EC4899',
    '#0EA5E9',
    '#14B8A6',
    '#65A30D',
    '#F97316',
    '#78716C',
  ];

  @override
  Widget build(BuildContext context) {
    return _OptionSheet(
      title: 'Pick a colour',
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final hex in _customColors)
              Semantics(
                button: true,
                selected: hex == selected,
                label: 'Event color $hex',
                child: GestureDetector(
                  onTap: () => onSelected(hex),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 58,
                    height: 58,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: parseHexColor(hex),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: hex == selected
                        ? const Icon(
                            Icons.check,
                            size: 24,
                            color: Colors.white,
                          )
                        : null,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
