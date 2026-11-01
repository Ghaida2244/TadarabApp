import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/calendar_event.dart';
import '../../models/course.dart';
import '../../models/enums.dart';
import '../../services/calendar_service.dart';
import '../../services/reminder_scheduler.dart';
import '../../theme/app_theme.dart';
import '../../utils/event_time.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_error_banner.dart';
import '../../widgets/color_picker_dialog.dart';
import '../../widgets/color_swatch_tile.dart';
import '../../widgets/screen_header.dart';
import '../../widgets/status_bar_style.dart';
import 'calendar_styles.dart';
import 'widgets/calendar_pickers.dart';
import 'widgets/reminder_card.dart';

/// Maximum length of an event name — `eventName` is VARCHAR(100) in the SRS
/// Attributes Dictionary Table. Not in the unified design, which sets no
/// limit; kept because the column does.
const int kEventNameMaxLength = 100;

/// Shown after saving when the student declined notification permission.
const kReminderPermissionDeniedMessage =
    "Event saved, but its reminder couldn't be set because notifications are "
    'turned off for Tadarab.';

/// Shown after saving when the platform refused to schedule the reminder.
const kReminderNotScheduledMessage =
    "Event saved, but its reminder couldn't be set.";

/// The reasons Save stays disabled, in the order the design checks them.
const kSaveReasonName = 'Add an event name to continue.';
const kSaveReasonColor = 'Pick a color to continue.';
const kSaveReasonDate = 'Pick a date to continue.';
const kSaveReasonTime = 'Pick a time to continue.';
const kSaveReasonReminder = 'Fix the reminder to continue.';

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
    required this.courses,
    this.reminderScheduler,
    this.now,
    this.random,
  });

  final String uid;
  final CalendarService calendarService;

  /// The student's courses, already fetched by the Calendar screen — so the
  /// feature reads them once, from one source, rather than per screen.
  final List<Course> courses;

  /// Overridable for tests; defaults to the real notification-backed one.
  final ReminderScheduler? reminderScheduler;

  /// Overridable for tests, so reminder validation is deterministic.
  final DateTime? now;

  /// Overridable for tests, so the one-time random default colour
  /// ([randomEventColor]) is deterministic given a seeded [Random].
  final Random? random;

  @override
  State<AddEventScreen> createState() => _AddEventScreenState();
}

class _AddEventScreenState extends State<AddEventScreen> {
  final _nameController = TextEditingController();

  late final ReminderScheduler _scheduler =
      widget.reminderScheduler ?? ReminderScheduler();

  Course? _selectedCourse;
  bool _coursesOpen = false;

  /// The screen's current colour selection — null only for the brief
  /// window before [_assignDefaultColor] has run (it needs the saved
  /// colours, which are fetched asynchronously). Never written to directly
  /// outside [_assignDefaultColor]/[_pickColor]/[_pickCustomColor]/
  /// [_removeSavedColor].
  String? _selectedColor;

  /// The one-time random default ([randomEventColor]), computed once by
  /// [_assignDefaultColor] and never recomputed afterwards. Kept
  /// separately from [_selectedColor] so that removing whichever saved
  /// tile the student has selected has something fixed to fall back to,
  /// without ever drawing a fresh random colour.
  String? _defaultColor;

  /// True once [_assignDefaultColor] has run — guards it from ever running
  /// a second time, since the random pick must happen exactly once per
  /// screen open and then stay fixed.
  bool _defaultColorAssigned = false;

  /// True once the student has explicitly picked a tile or a dialog
  /// colour — after that, [_assignDefaultColor] must never override her
  /// choice, even if it's still resolving when she picks.
  bool _colorPickedByUser = false;

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  /// The student's saved quick-colours, fetched once when this screen
  /// opens — also exactly the "standalone event colours" [randomEventColor]
  /// excludes, since a saved colour is by definition one a standalone event
  /// already uses. Starts empty, which [_assignDefaultColor] treats as "no
  /// standalone colours to exclude"; a failed read falls back to the same.
  List<String> _savedColors = [];

  bool _reminderEnabled = false;

  /// The last amount that was a whole number inside 1–60. Always safe to
  /// save; the box may transiently hold something else while being typed.
  int _reminderAmount = 1;

  /// True while the amount box holds an empty or out-of-range value. The
  /// reminder is incomplete until it clears, so Save waits.
  bool _reminderAmountIncomplete = false;

  ReminderUnit _reminderUnit = ReminderUnit.days;
  bool _unitsOpen = false;

  bool _saving = false;
  String? _errorMessage;

  DateTime get _now => widget.now ?? DateTime.now();

  /// A course's colour wins over the presets — the chip says the event
  /// "will use this course color", so the picker is replaced, not merely
  /// overridden. Null only while no course is selected and the one-time
  /// default hasn't resolved yet — [_saveReason] gates Save on that.
  String? get _effectiveColor => _selectedCourse?.color ?? _selectedColor;

  bool get _nameFilled => _nameController.text.trim().isNotEmpty;

  /// True when the enabled reminder can't be used as it stands — either its
  /// amount box is empty/out of range, or its lead time has already passed.
  bool get _reminderInvalid =>
      _reminderEnabled && (_reminderAmountIncomplete || _reminderLeadPassed);

  /// True when the enabled reminder's lead time has already passed.
  bool get _reminderLeadPassed =>
      _reminderEnabled &&
      reminderLeadPassed(
        date: _selectedDate,
        time: _selectedTime,
        amount: _reminderAmount,
        unit: _reminderUnit,
        now: _now,
      );

  /// Why Save is disabled, or null when the form is ready to submit.
  String? get _saveReason {
    if (!_nameFilled) return kSaveReasonName;
    if (_effectiveColor == null) return kSaveReasonColor;
    if (_selectedDate == null) return kSaveReasonDate;
    if (_selectedTime == null) return kSaveReasonTime;
    if (_reminderInvalid) return kSaveReasonReminder;
    return null;
  }

  @override
  void initState() {
    super.initState();
    _loadSavedColors();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedColors() async {
    var saved = const <String>[];
    try {
      saved = await widget.calendarService.loadSavedEventColors(widget.uid);
    } catch (_) {
      // Never blocks the form: the default below still gets assigned, just
      // with no standalone colours to exclude, and the row falls back to
      // showing only the default tile and the "+".
    }
    if (!mounted) return;
    setState(() {
      _savedColors = saved;
      _assignDefaultColor();
    });
  }

  /// Picks the one-time random default and, unless the student has already
  /// picked something herself in the meantime, selects it. Guarded by
  /// [_defaultColorAssigned] so this can only ever run once per screen
  /// open — the pick itself must never change afterwards, including on a
  /// later reload.
  void _assignDefaultColor() {
    if (_defaultColorAssigned) return;
    _defaultColorAssigned = true;
    _defaultColor = randomEventColor(
      courseColors: widget.courses.map((c) => c.color),
      standaloneColors: _savedColors,
      random: widget.random,
    );
    if (!_colorPickedByUser) _selectedColor = _defaultColor;
  }

  /// Drops [hex] from the saved list immediately (no confirmation) and, if
  /// it was the selected colour, falls back to the fixed one-time default
  /// — never a freshly-drawn random colour.
  /// The Firestore write is fire-and-forget — best effort, and never
  /// touches any event.
  void _removeSavedColor(String hex) {
    setState(() {
      _savedColors = _savedColors
          .where((c) => c.toUpperCase() != hex.toUpperCase())
          .toList();
      if (_selectedColor != null &&
          _selectedColor!.toUpperCase() == hex.toUpperCase()) {
        _selectedColor = _defaultColor;
        _colorPickedByUser = false;
      }
    });
    unawaited(widget.calendarService.removeSavedEventColor(widget.uid, hex));
  }

  Future<void> _pickDate() async {
    final picked = await pickEventDate(
      context: context,
      initialDate: _selectedDate ?? _now,
      now: _now,
    );
    if (picked == null) return;
    setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await pickEventTime(
      context: context,
      initialTime: _selectedTime,
      now: _now,
    );
    if (picked == null) return;
    setState(() => _selectedTime = picked);
  }

  /// Shows why a reminder change was refused. The reminder card rejects the
  /// value itself; this only surfaces the explanation.
  void _onReminderRejected(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: AppColors.navy,
          content: Text(
            message,
            style: CalendarText.save.copyWith(fontSize: 14),
          ),
        ),
      );
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
    // Save is disabled until the form is valid, so there is nothing left to
    // validate here — the reason line below the button carries the feedback.
    if (_saveReason != null) return;

    setState(() {
      _errorMessage = null;
      _saving = true;
    });

    final event = CalendarEvent(
      // Replaced by the ID reserved just below; the model requires a
      // non-null eventId and this value is never stored.
      eventId: '',
      eventName: _nameController.text.trim(),
      eventDate: DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
      ),
      eventTime: formatEventTimeForStorage(_selectedTime!),
      reminderEnabled: _reminderEnabled,
      reminderBefore: _reminderEnabled ? _reminderAmount : null,
      reminderUnit: _reminderEnabled ? _reminderUnit : null,
      color: _effectiveColor!,
      // Filled in from the signed-in student by CalendarService.addEvent;
      // this screen has no access to the student's email.
      email: '',
      courseId: _selectedCourse?.courseId,
    );

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
      } else if (await _scheduler.scheduleReminder(
        requested,
        courseName: _selectedCourse?.courseName,
      )) {
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

      // Only a standalone event's colour feeds the saved list — a
      // course-linked event's colour comes from the course, not a pick of
      // its own. Fire-and-forget: best effort, never delays the pop below.
      if (_selectedCourse == null) {
        unawaited(
          widget.calendarService.recordStandaloneEventColor(
            widget.uid,
            toSave.color,
          ),
        );
      }

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
              style: CalendarText.save.copyWith(fontSize: 14),
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
    final reason = _saveReason;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: statusBarStyleFor(AppColors.navy),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          children: [
            ScreenHeader(
              title: 'Add Event',
              subtitle: 'Add an event to your calendar',
              backgroundColor: AppColors.navy,
              onClose: _saving ? null : () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_errorMessage != null) ...[
                      AppErrorBanner(
                        heading: "Couldn't save your event",
                        body: _errorMessage!,
                      ),
                      const SizedBox(height: 24),
                    ],

                    const _FieldLabel('EVENT NAME'),
                    const SizedBox(height: 8),
                    _FieldBox(
                      filled: _nameFilled,
                      child: TextField(
                        key: const ValueKey('event-name'),
                        controller: _nameController,
                        enabled: !_saving,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(kEventNameMaxLength),
                        ],
                        style: CalendarText.fieldInput(AppColors.navy),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          hintText: 'e.g. Midterm exam, Assignment 1',
                          hintStyle: CalendarText.fieldInput(
                            AppColors.placeholder,
                          ),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(height: 24),

                    const _FieldLabel('COURSE', optional: '· OPTIONAL'),
                    const SizedBox(height: 8),
                    _CourseField(
                      courses: widget.courses,
                      selected: _selectedCourse,
                      open: _coursesOpen,
                      enabled: !_saving,
                      onToggle: () =>
                          setState(() => _coursesOpen = !_coursesOpen),
                      onSelected: (course) => setState(() {
                        _selectedCourse = course;
                        _coursesOpen = false;
                      }),
                    ),

                    if (_selectedCourse == null) ...[
                      const SizedBox(height: 24),
                      const _FieldLabel('EVENT COLOR'),
                      const SizedBox(height: 10),
                      _ColorSwatchGrid(
                        tiles: eventColorTiles(
                          savedColors: _savedColors,
                          courseColors: widget.courses.map((c) => c.color),
                          selectedColor: _selectedColor,
                        ),
                        selected: _selectedColor,
                        onSelected: (hex) => setState(() {
                          _selectedColor = hex;
                          _colorPickedByUser = true;
                        }),
                        onCustom: _pickCustomColor,
                        onRemove: _removeSavedColor,
                      ),
                    ],

                    const SizedBox(height: 24),
                    const _FieldLabel('DATE'),
                    const SizedBox(height: 8),
                    _PickerField(
                      fieldKey: const ValueKey('event-date'),
                      enabled: !_saving,
                      onTap: _pickDate,
                      placeholder: 'Select a date',
                      value: _selectedDate == null
                          ? null
                          : formatLongDate(_selectedDate!),
                    ),

                    const SizedBox(height: 24),
                    const _FieldLabel('TIME'),
                    const SizedBox(height: 8),
                    _PickerField(
                      fieldKey: const ValueKey('event-time'),
                      enabled: !_saving,
                      onTap: _pickTime,
                      placeholder: 'Select a time',
                      value: _selectedTime == null
                          ? null
                          : formatEventTimeForDisplay(_selectedTime!),
                    ),

                    const SizedBox(height: 24),
                    ReminderCard(
                      enabled: _reminderEnabled,
                      amount: _reminderAmount,
                      unit: _reminderUnit,
                      unitsOpen: _unitsOpen,
                      date: _selectedDate,
                      time: _selectedTime,
                      now: _now,
                      onToggled: (value) => setState(() {
                        _reminderEnabled = value;
                        _unitsOpen = false;
                        // The card rebuilds its box from _reminderAmount, so a
                        // half-typed value can't survive a toggle.
                        _reminderAmountIncomplete = false;
                      }),
                      onAmountChanged: (value) => setState(() {
                        _reminderAmountIncomplete = value == null;
                        if (value != null) _reminderAmount = value;
                      }),
                      onUnitChanged: (value) => setState(() {
                        _reminderUnit = value;
                        _unitsOpen = false;
                      }),
                      onToggleUnits: () =>
                          setState(() => _unitsOpen = !_unitsOpen),
                      onRejected: _onReminderRejected,
                    ),
                  ],
                ),
              ),
            ),
            // Pinned footer, outside the scroll area.
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 26),
              child: Column(
                children: [
                  Semantics(
                    button: true,
                    enabled: reason == null && !_saving,
                    // A disabled AppButton has no onPressed, so a screen
                    // reader would otherwise announce nothing at all; the
                    // reason travels with the button instead.
                    hint: reason,
                    child: AppButton(
                      label: 'Save Event',
                      variant: AppButtonVariant.accent,
                      height: 56,
                      borderRadius: 18,
                      fontSize: 16,
                      loading: _saving,
                      loadingLabel: 'Saving…',
                      disabledBackgroundColor: AppColors.disabledRedFill,
                      disabledRemovesShadow: true,
                      onPressed: reason == null && !_saving ? _save : null,
                    ),
                  ),
                  // Only while the form is incomplete: once saving starts the
                  // button itself says "Saving…" and the reason is moot.
                  if (reason != null && !_saving) ...[
                    const SizedBox(height: 9),
                    Text(
                      reason,
                      key: const ValueKey('save-reason'),
                      textAlign: TextAlign.center,
                      style: CalendarText.saveReason,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickCustomColor() async {
    final initial = parseHexColor(
      _selectedColor ?? _defaultColor ?? kEventSwatchPool.first,
    );
    final picked = await showColorPicker(context: context, initial: initial);
    if (picked == null) return;
    setState(() {
      _selectedColor = hexFromColor(picked);
      _colorPickedByUser = true;
    });
  }
}

/// An all-caps field label, e.g. "EVENT NAME" or "COURSE · OPTIONAL".
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text, {this.optional});

  final String text;

  /// The lighter "· OPTIONAL" half, when there is one.
  final String? optional;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: text,
        style: CalendarText.fieldLabel,
        children: optional == null
            ? null
            : [
                TextSpan(
                  text: ' $optional',
                  style: CalendarText.fieldLabelOptional,
                ),
              ],
      ),
    );
  }
}

/// The white rounded box every field sits in. Its border reads the field's
/// state: navy once filled or open, otherwise the default light edge.
///
/// Separate from the shared `AppTextField` because these have no leading
/// icon and their label sits outside the box.
class _FieldBox extends StatelessWidget {
  const _FieldBox({required this.child, this.filled = false});

  final Widget child;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: filled ? AppColors.navy : AppColors.borderLight,
          width: 2,
        ),
      ),
      child: child,
    );
  }
}

/// A [_FieldBox] that opens a picker instead of accepting typed input.
class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.fieldKey,
    required this.enabled,
    required this.onTap,
    required this.placeholder,
    required this.value,
  });

  final Key fieldKey;
  final bool enabled;
  final VoidCallback onTap;
  final String placeholder;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: fieldKey,
      onTap: enabled ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: _FieldBox(
        filled: value != null,
        child: Text(
          value ?? placeholder,
          style: CalendarText.fieldInput(
            value == null ? AppColors.placeholder : AppColors.navy,
          ),
        ),
      ),
    );
  }
}

/// The course field plus its inline dropdown and selected-course chip.
class _CourseField extends StatelessWidget {
  const _CourseField({
    required this.courses,
    required this.selected,
    required this.open,
    required this.enabled,
    required this.onToggle,
    required this.onSelected,
  });

  final List<Course> courses;
  final Course? selected;
  final bool open;
  final bool enabled;
  final VoidCallback onToggle;
  final ValueChanged<Course?> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          key: const ValueKey('course-field'),
          onTap: enabled ? onToggle : null,
          behavior: HitTestBehavior.opaque,
          child: _FieldBox(
            filled: open || selected != null,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    selected?.courseName ?? 'No course selected',
                    style: CalendarText.fieldInput(
                      selected == null ? AppColors.placeholder : AppColors.navy,
                    ),
                  ),
                ),
                Icon(
                  open ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                  size: 22,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
        if (open) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                const BoxShadow(color: AppColors.cardTint, spreadRadius: 2),
                BoxShadow(
                  color: AppColors.navy.withValues(alpha: 0.06),
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                _CourseOption(
                  label: 'No course selected',
                  hue: AppColors.borderLight,
                  selected: selected == null,
                  onTap: () => onSelected(null),
                ),
                // Not in the handoff, whose course list is never empty.
                if (courses.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                    child: Text(
                      "You haven't added any courses yet. Events can still "
                      'be saved without one.',
                      style: CalendarText.courseEmpty,
                    ),
                  )
                else
                  for (final course in courses)
                    _CourseOption(
                      label: course.courseName,
                      hue: parseHexColor(course.color),
                      selected: course.courseId == selected?.courseId,
                      onTap: () => onSelected(course),
                    ),
              ],
            ),
          ),
        ],
        if (selected != null) ...[
          const SizedBox(height: 14),
          _CourseColorChip(course: selected!),
        ],
      ],
    );
  }
}

/// One row in the inline course dropdown.
class _CourseOption extends StatelessWidget {
  const _CourseOption({
    required this.label,
    required this.hue,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color hue;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: ValueKey('course-option-$label'),
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? CalendarColors.selectedRow : Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(color: hue, shape: BoxShape.circle),
            ),
            const SizedBox(width: 11),
            Expanded(child: Text(label, style: CalendarText.courseOption)),
          ],
        ),
      ),
    );
  }
}

/// Replaces the swatch row once a course is chosen.
class _CourseColorChip extends StatelessWidget {
  const _CourseColorChip({required this.course});

  final Course course;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: AppColors.cardTint, spreadRadius: 2),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: parseHexColor(course.color),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(course.courseName, style: CalendarText.chipName),
                const SizedBox(height: 1),
                Text(
                  'Event will use this course color',
                  style: CalendarText.chipCaption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The saved/default/selected colour tiles plus the rainbow "+" for a
/// custom colour, in the same 5-column grid as Add course's colour grid so
/// the two screens' pickers look and size identically.
class _ColorSwatchGrid extends StatelessWidget {
  const _ColorSwatchGrid({
    required this.tiles,
    required this.selected,
    required this.onSelected,
    required this.onCustom,
    required this.onRemove,
  });

  final List<EventColorTile> tiles;
  final String? selected;
  final ValueChanged<String> onSelected;
  final VoidCallback onCustom;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 5,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      // Without an explicit padding, a ListView/GridView pads itself with
      // the ambient MediaQuery safe-area insets (status bar / nav bar) —
      // meant for a full-bleed scrollable, not this short, shrink-wrapped
      // grid sitting inside an already-padded SingleChildScrollView. This
      // screen's body (unlike Add course's, which wraps its whole body in
      // SafeArea) has no SafeArea around the scroll area, so that padding
      // leaked straight through and showed up as two large gaps around the
      // colour tiles on a real device — invisible in a widget test, whose
      // default MediaQuery has zero padding.
      padding: EdgeInsets.zero,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1,
      children: [
        for (final tile in tiles)
          ColorSwatchTile(
            key: ValueKey(tile.hex),
            color: parseHexColor(tile.hex),
            hex: tile.hex,
            selected: tile.hex.toUpperCase() == selected?.toUpperCase(),
            onTap: () => onSelected(tile.hex),
            onRemove: tile.removable ? () => onRemove(tile.hex) : null,
          ),
        // Never shown as selected: a colour picked from its dialog gets its
        // own extra tile (added by `eventColorTiles`) rather than marking
        // the "+" itself — unlike Add course, which has no such extra tile
        // and so marks the "+" directly instead.
        CustomColorSwatchTile(
          key: const ValueKey('custom-color'),
          selected: false,
          onTap: onCustom,
        ),
      ],
    );
  }
}
