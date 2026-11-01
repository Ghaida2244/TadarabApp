import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/profile_service.dart';
import '../../services/reminder_scheduler.dart';
import '../../theme/app_theme.dart';
import '../../utils/event_time.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_error_banner.dart';
import '../../widgets/screen_header.dart';
import '../../widgets/status_bar_style.dart';
import '../calendar/widgets/calendar_pickers.dart';
import 'profile_styles.dart';
import 'widgets/profile_header.dart';

/// Shown when the toggle is on but no time has been chosen yet.
const kPickTimeNote = 'Pick a time to finish setting this up.';

/// Shown after saving when the student declined notification permission.
const kStudyReminderPermissionDeniedMessage =
    "Reminder saved as off, because notifications are turned off for "
    'Tadarab.';

/// Shown after saving when the platform refused to schedule the reminder.
const kStudyReminderNotScheduledMessage =
    "Reminder saved as off, because it couldn't be scheduled.";

/// Confirmation shown on the Profile screen after a successful save.
String studyReminderSavedMessage(TimeOfDay? time) => time == null
    ? 'Study reminder turned off'
    : 'Study reminder set for ${formatEventTimeForDisplay(time)}';

/// The Study Reminder screen: a daily notification at a time the student
/// picks.
///
/// Defaults to off with no time set, matching the Attributes Dictionary's
/// `reminderEnabled: false` / `reminderTime: null`.
///
/// Uses the themed Material time picker the Calendar uses
/// (`calendar_pickers.dart`) rather than the design's custom hour/minute
/// sheet — a team decision for consistency across the app, recorded in
/// CLAUDE.md.
class StudyReminderScreen extends StatefulWidget {
  const StudyReminderScreen({
    super.key,
    required this.uid,
    required this.enabled,
    required this.time,
    required this.profileService,
    this.reminderScheduler,
    this.now,
  });

  final String uid;

  /// The stored state this screen opens on.
  final bool enabled;
  final TimeOfDay? time;

  final ProfileService profileService;

  /// Overridable for tests; defaults to the real notification-backed one.
  final ReminderScheduler? reminderScheduler;

  /// Overridable "now" for the time picker's fallback when no time is
  /// saved yet; defaults to [DateTime.now] so tests can inject a fixed
  /// clock. Same pattern as the Calendar screen's own `widget.now`.
  final DateTime? now;

  @override
  State<StudyReminderScreen> createState() => _StudyReminderScreenState();
}

class _StudyReminderScreenState extends State<StudyReminderScreen> {
  late final ReminderScheduler _scheduler =
      widget.reminderScheduler ?? ReminderScheduler();

  DateTime get _now => widget.now ?? DateTime.now();

  late bool _draftEnabled = widget.enabled;
  late TimeOfDay? _draftTime = widget.time;

  bool _saving = false;
  String? _errorMessage;

  /// Whether anything actually changed — Save stays dead otherwise, as the
  /// design gates it.
  bool get _dirty {
    if (_draftEnabled != widget.enabled) return true;
    if (!_draftEnabled) return false;
    return _draftTime != widget.time;
  }

  /// Turning the reminder on requires a time; turning it off never does.
  bool get _valid => !_draftEnabled || _draftTime != null;

  bool get _canSave => _dirty && _valid && !_saving;

  Future<void> _pickTime() async {
    final picked = await pickEventTime(
      context: context,
      initialTime: _draftTime,
      now: _now,
    );
    if (picked == null) return;
    setState(() => _draftTime = picked);
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    // Scheduled before the write, so the stored flag can record what is
    // actually true on the device rather than what was asked for — the same
    // rule the Calendar's event reminders follow.
    String? notice;
    var effectiveEnabled = _draftEnabled;

    if (_draftEnabled && _draftTime != null) {
      if (!await _scheduler.requestPermission()) {
        effectiveEnabled = false;
        notice = kStudyReminderPermissionDeniedMessage;
      } else if (!await _scheduler.scheduleDailyStudyReminder(_draftTime!)) {
        effectiveEnabled = false;
        notice = kStudyReminderNotScheduledMessage;
      }
    } else {
      // Turning it off must also clear anything already scheduled.
      await _scheduler.cancelDailyStudyReminder();
    }

    try {
      await widget.profileService.updateStudyReminder(
        widget.uid,
        enabled: effectiveEnabled,
        time: effectiveEnabled ? _draftTime : null,
      );

      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop(true);
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: AppColors.navy,
          content: Text(
            notice ??
                studyReminderSavedMessage(effectiveEnabled ? _draftTime : null),
            style: ProfileText.save.copyWith(fontSize: 14),
          ),
        ),
      );
    } on ProfileFailure catch (failure) {
      // The write failed, so nothing should be left scheduled on its behalf.
      if (effectiveEnabled) await _scheduler.cancelDailyStudyReminder();
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errorMessage = failure.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasTime = _draftTime != null;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: statusBarStyleFor(AppColors.navy),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          children: [
            ScreenHeader(
              title: 'Study Reminder',
              backgroundColor: AppColors.navy,
              icon: Icons.chevron_left,
              semanticLabel: 'Back',
              buttonOnStart: true,
              onClose: _saving ? null : () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_errorMessage != null) ...[
                      AppErrorBanner(
                        heading: "Couldn't save your reminder",
                        body: _errorMessage!,
                      ),
                      const SizedBox(height: 14),
                    ],
                    GestureDetector(
                      key: const ValueKey('study-reminder-toggle'),
                      onTap: _saving
                          ? null
                          : () =>
                                setState(() => _draftEnabled = !_draftEnabled),
                      behavior: HitTestBehavior.opaque,
                      child: ProfileCard(
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _draftEnabled
                                    ? AppColors.cardTint
                                    : AppColors.surfaceMuted,
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: Icon(
                                Icons.notifications_none,
                                size: 19,
                                color: _draftEnabled
                                    ? AppColors.navy
                                    : AppColors.textOnDisabled,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Enable Reminder',
                                    style: ProfileText.reminderTitle,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Get a daily nudge to study',
                                    style: ProfileText.reminderSubtitle,
                                  ),
                                ],
                              ),
                            ),
                            // Hand-built so it matches the design's 54x31
                            // pill, which Material's Switch can't be sized to.
                            Container(
                              width: 54,
                              height: 31,
                              padding: const EdgeInsets.all(3),
                              alignment: _draftEnabled
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              decoration: BoxDecoration(
                                color: _draftEnabled
                                    ? AppColors.navy
                                    : AppColors.borderLight,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Container(
                                width: 25,
                                height: 25,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.navy.withValues(
                                        alpha: 0.3,
                                      ),
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
                    ),
                    if (_draftEnabled) ...[
                      const SizedBox(height: 14),
                      ProfileCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.schedule,
                                  size: 17,
                                  color: AppColors.navy,
                                ),
                                const SizedBox(width: 9),
                                Text(
                                  'Reminder Time',
                                  style: ProfileText.reminderSectionTitle,
                                ),
                              ],
                            ),
                            const SizedBox(height: 11),
                            GestureDetector(
                              key: const ValueKey('reminder-time-field'),
                              onTap: _saving ? null : _pickTime,
                              behavior: HitTestBehavior.opaque,
                              child: Container(
                                height: 56,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 15,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceMuted,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: hasTime
                                        ? AppColors.borderLight
                                        : AppColors.red,
                                    width: 2,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        hasTime
                                            ? formatEventTimeForDisplay(
                                                _draftTime!,
                                              )
                                            : '--:-- --',
                                        key: const ValueKey('reminder-time'),
                                        style: ProfileText.reminderTime(
                                          hasTime
                                              ? AppColors.navy
                                              : AppColors.placeholder,
                                        ),
                                      ),
                                    ),
                                    const Icon(
                                      Icons.schedule,
                                      size: 18,
                                      color: AppColors.textSecondary,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 11),
                            Text(
                              hasTime
                                  ? "You'll receive a reminder at "
                                        '${formatEventTimeForDisplay(_draftTime!)} '
                                        'every day.'
                                  : kPickTimeNote,
                              key: const ValueKey('reminder-helper'),
                              style: ProfileText.reminderHelper(
                                hasTime
                                    ? AppColors.successDark
                                    : AppColors.errorBannerBody,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 26),
              child: AppButton(
                label: 'Save Changes',
                variant: AppButtonVariant.accent,
                height: 56,
                borderRadius: 18,
                fontSize: 16,
                loading: _saving,
                loadingLabel: 'Saving…',
                disabledBackgroundColor: AppColors.disabledRedFill,
                disabledRemovesShadow: true,
                onPressed: _canSave ? _save : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
