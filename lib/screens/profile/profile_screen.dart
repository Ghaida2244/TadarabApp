import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/student.dart';
import '../../services/home_data_service.dart';
import '../../services/profile_service.dart';
import '../../services/reminder_scheduler.dart';
import '../../theme/app_theme.dart';
import '../../utils/event_time.dart';
import '../../utils/rank.dart';
import '../../widgets/app_error_banner.dart';
import '../../widgets/status_bar_style.dart';
import 'about_document_screen.dart';
import 'content/about_content.dart';
import 'edit_profile_screen.dart';
import 'learning_guide_screen.dart';
import 'profile_styles.dart';
import 'ranks_screen.dart';
import 'study_reminder_screen.dart';
import 'widgets/logout_dialog.dart';
import 'widgets/profile_header.dart';
import 'widgets/rank_icon.dart';
import 'widgets/rank_progress_card.dart';

/// The Profile tab: the student's name and avatar, their points and rank,
/// the Study Reminder setting, the About documents, and Log Out.
///
/// Rank is always derived from `totalPoints` via `rankForPoints`, never read
/// from the stored `Student.currentRank` — see `lib/utils/rank.dart` for why
/// that field is currently left unwritten.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.uid,
    this.homeDataService,
    this.profileService,
    this.reminderScheduler,
    this.onSignOut,
  });

  final String uid;

  /// Source of the live student document. Defaults to the real
  /// Firestore-backed service; overridable for tests.
  final HomeDataService? homeDataService;

  /// Writes the student's own fields. Overridable for tests.
  final ProfileService? profileService;

  /// Schedules the daily study reminder. Overridable for tests.
  final ReminderScheduler? reminderScheduler;

  /// Signs the student out, after the confirmation dialog. Passed down from
  /// the navigation shell, which owns the auth service.
  final VoidCallback? onSignOut;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final HomeDataService _dataService =
      widget.homeDataService ?? HomeDataService();
  late final ProfileService _profileService =
      widget.profileService ?? ProfileService();

  /// Bumped to resubscribe the student stream after a retry.
  int _retryToken = 0;

  Future<void> _openEdit(Student student) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(
          uid: widget.uid,
          name: student.name,
          email: student.email,
          profileService: _profileService,
        ),
      ),
    );
    // No reload needed: the student stream pushes the new name on its own.
  }

  void _openRanks(Student student) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RanksScreen(points: student.totalPoints),
      ),
    );
  }

  void _openStudyReminder(Student student) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StudyReminderScreen(
          uid: widget.uid,
          enabled: student.reminderEnabled,
          time: student.reminderTime == null
              ? null
              : parseEventTime(student.reminderTime!),
          profileService: _profileService,
          reminderScheduler: widget.reminderScheduler,
        ),
      ),
    );
  }

  /// [student] is already in hand from the Profile screen's own
  /// `StreamBuilder` — never an extra read just to open the guide. Null
  /// only while the student hasn't loaded yet, in which case the Learning
  /// Guide falls back to its own "no progress" default rather than
  /// crashing on a missing value.
  void _openDocument(AboutDocumentKind kind, Student? student) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => switch (kind) {
          AboutDocumentKind.aboutUs => const AboutDocumentScreen(
            document: kAboutUsDocument,
          ),
          AboutDocumentKind.privacyPolicy => const AboutDocumentScreen(
            document: kPrivacyPolicyDocument,
          ),
          AboutDocumentKind.termsOfUse => const AboutDocumentScreen(
            document: kTermsOfUseDocument,
          ),
          AboutDocumentKind.learningGuide => LearningGuideScreen(
            points: student?.totalPoints,
          ),
        },
      ),
    );
  }

  Future<void> _confirmLogOut() async {
    final confirmed = await showLogOutDialog(context);
    if (!confirmed) return;
    widget.onSignOut?.call();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: statusBarStyleFor(AppColors.navy),
      child: Container(
        color: Colors.white,
        child: StreamBuilder<Student?>(
          key: ValueKey('profile-$_retryToken'),
          stream: _dataService.watchStudent(widget.uid),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _ProfileError(
                onRetry: () => setState(() => _retryToken++),
              );
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final student = snapshot.data;
            if (student == null) {
              return _ProfileError(
                onRetry: () => setState(() => _retryToken++),
              );
            }

            return Column(
              children: [
                ProfileAvatarHeader(
                  name: student.name,
                  onEdit: () => _openEdit(student),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Student Summary',
                          style: ProfileText.sectionTitle,
                        ),
                        const SizedBox(height: 11),
                        _SummaryRow(points: student.totalPoints),
                        const SizedBox(height: 11),
                        RankProgressCard(
                          points: student.totalPoints,
                          onViewRanks: () => _openRanks(student),
                        ),
                        const SizedBox(height: 22),
                        Text('Settings', style: ProfileText.sectionTitle),
                        const SizedBox(height: 11),
                        _SettingsRow(
                          student: student,
                          onTap: () => _openStudyReminder(student),
                        ),
                        const SizedBox(height: 22),
                        Text('About', style: ProfileText.sectionTitle),
                        const SizedBox(height: 11),
                        _AboutRows(
                          onOpen: (kind) => _openDocument(kind, student),
                        ),
                        const SizedBox(height: 22),
                        _LogOutButton(onTap: _confirmLogOut),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The Total Points and Rank cards side by side.
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.points});

  final int points;

  @override
  Widget build(BuildContext context) {
    final rank = rankForPoints(points);

    // IntrinsicHeight so the two cards match height like the design's flex
    // row does. `stretch` alone would demand an infinite height here, since
    // the row sits inside a vertically scrolling parent.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ProfileCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.errorBannerBackground,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.emoji_events_outlined,
                      size: 20,
                      color: AppColors.red,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Total Points', style: ProfileText.summaryLabel),
                  const SizedBox(height: 8),
                  Text(
                    formatPoints(points),
                    key: const ValueKey('profile-points'),
                    style: ProfileText.summaryPoints,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: ProfileCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      // The design tints the chip with the rank's own
                      // colour at 12% (`hue + '1F'`).
                      color: rank.color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: RankIcon(
                      tier: rank.tier,
                      color: rank.color,
                      size: 20,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Rank', style: ProfileText.summaryLabel),
                  const SizedBox(height: 8),
                  Text(
                    rank.shortName,
                    key: const ValueKey('profile-rank'),
                    textAlign: TextAlign.center,
                    style: ProfileText.summaryRank,
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

/// The Study Reminder row, with its live on/off summary.
class _SettingsRow extends StatelessWidget {
  const _SettingsRow({required this.student, required this.onTap});

  final Student student;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final time = student.reminderTime;
    final on = student.reminderEnabled && time != null;
    final summary = on ? 'Daily at ${formatStoredTimeForDisplay(time)}' : 'Off';

    return GestureDetector(
      key: const ValueKey('study-reminder-row'),
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: ProfileCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        borderRadius: 18,
        child: Row(
          children: [
            const _RowIcon(icon: Icons.notifications_none),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Study Reminder', style: ProfileText.rowTitle),
                  const SizedBox(height: 2),
                  Text(
                    summary,
                    key: const ValueKey('reminder-summary'),
                    style: ProfileText.rowSummary(
                      on ? AppColors.success : AppColors.placeholder,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 17,
              color: AppColors.textOnDisabled,
            ),
          ],
        ),
      ),
    );
  }
}

/// The four About rows, in the design's order.
class _AboutRows extends StatelessWidget {
  const _AboutRows({required this.onOpen});

  final ValueChanged<AboutDocumentKind> onOpen;

  static const _rows = [
    (AboutDocumentKind.aboutUs, 'About Us', Icons.info_outline),
    (
      AboutDocumentKind.learningGuide,
      'Learning Guide',
      Icons.menu_book_outlined,
    ),
    (AboutDocumentKind.privacyPolicy, 'Privacy Policy', Icons.shield_outlined),
    (AboutDocumentKind.termsOfUse, 'Terms of Use', Icons.description_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final (kind, label, icon) in _rows) ...[
          GestureDetector(
            key: ValueKey('about-row-$label'),
            onTap: () => onOpen(kind),
            behavior: HitTestBehavior.opaque,
            child: ProfileCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              borderRadius: 18,
              child: Row(
                children: [
                  _RowIcon(icon: icon),
                  const SizedBox(width: 12),
                  Expanded(child: Text(label, style: ProfileText.rowTitle)),
                  const Icon(
                    Icons.chevron_right,
                    size: 17,
                    color: AppColors.textOnDisabled,
                  ),
                ],
              ),
            ),
          ),
          if (label != _rows.last.$2) const SizedBox(height: 9),
        ],
      ],
    );
  }
}

/// The 34px tinted square an About or Settings row leads with.
class _RowIcon extends StatelessWidget {
  const _RowIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.cardTint,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 17, color: AppColors.navy),
    );
  }
}

/// The tinted red Log Out button at the foot of the screen.
class _LogOutButton extends StatelessWidget {
  const _LogOutButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: ProfileColors.logOutFill,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: ProfileColors.logOutBorder, width: 2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.logout, size: 17, color: AppColors.red),
            const SizedBox(width: 9),
            Text('Log Out', style: ProfileText.logOut),
          ],
        ),
      ),
    );
  }
}

/// Shown when the student document can't be read.
class _ProfileError extends StatelessWidget {
  const _ProfileError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppErrorBanner(
              heading: "Couldn't load your profile",
              body: 'Check your connection and try again.',
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: onRetry,
              behavior: HitTestBehavior.opaque,
              child: Text('Try again', style: AppTypography.link),
            ),
          ],
        ),
      ),
    );
  }
}
