import 'package:flutter/material.dart';

import '../../services/profile_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/keyboard_safe_padding.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_error_banner.dart';
import '../../widgets/dismiss_keyboard_on_tap.dart';
import 'profile_styles.dart';
import 'widgets/profile_header.dart';

/// The note under the locked email field, as the design words it.
const kEmailLockedNote = "Your email can't be changed here.";

/// The note under the name field while it is empty.
const kNameRequiredNote = 'Your name cannot be empty.';

/// The note under the name field otherwise.
const kNameHelpNote = 'This is the name shown on your profile and home screen.';

/// Edit Profile: changes the student's display name.
///
/// **A team decision that departs from the SRS.** `Edit Account Page.png`
/// offers Change Name, Change Email *and* Change Password (with a current-
/// password confirmation); the unified design replaces it with name-only
/// editing and an explicitly locked email, and that is what is built here.
/// Recorded in CLAUDE.md. Consequences: no reauthentication flow, no
/// verified email change, and none of the SRS's duplicate-email validation
/// — a duplicate email is unreachable when email can't be edited.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({
    super.key,
    required this.uid,
    required this.name,
    required this.email,
    required this.profileService,
  });

  final String uid;

  /// The name as currently stored; seeds the field and defines "changed".
  final String name;

  /// Shown read-only.
  final String email;

  final ProfileService profileService;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.name);

  bool _saving = false;
  String? _errorMessage;

  String get _trimmed => _controller.text.trim();

  /// Save stays dead until the name is both non-empty and actually
  /// different, exactly as the design gates it.
  bool get _canSave => _trimmed.isNotEmpty && _trimmed != widget.name.trim();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_canSave || _saving) return;
    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    try {
      await widget.profileService.updateName(widget.uid, _trimmed);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ProfileFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errorMessage = failure.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final nameEmpty = _trimmed.isEmpty;

    return Scaffold(
      backgroundColor: Colors.white,
      // The Save Changes footer below is pinned outside the scroll area,
      // at the bottom of the Column — without this, opening the keyboard
      // (typing the name) shrinks the Scaffold's body and drags that
      // footer up above it instead of letting the keyboard simply cover
      // it. See keyboardSafePadding below for the matching fix on the
      // scroll view's own padding.
      resizeToAvoidBottomInset: false,
      body: DismissKeyboardOnTap(
        child: Column(
        children: [
          ProfileSubHeader(title: 'Edit Profile', enabled: !_saving),
          Expanded(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: keyboardSafePadding(
                context,
                const EdgeInsets.fromLTRB(22, 22, 22, 12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_errorMessage != null) ...[
                    AppErrorBanner(
                      heading: "Couldn't save your changes",
                      body: _errorMessage!,
                    ),
                    const SizedBox(height: 20),
                  ],
                  Text('NAME', style: ProfileText.fieldLabel),
                  const SizedBox(height: 10),
                  Container(
                    height: 56,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: nameEmpty
                            ? AppColors.red
                            : AppColors.borderLight,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.person_outline,
                          size: 18,
                          color: AppColors.placeholder,
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: TextField(
                            key: const ValueKey('profile-name'),
                            controller: _controller,
                            enabled: !_saving,
                            style: ProfileText.fieldInput(AppColors.navy),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              isDense: true,
                              hintText: 'Your name',
                              hintStyle: ProfileText.fieldInput(
                                AppColors.placeholder,
                              ),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    nameEmpty ? kNameRequiredNote : kNameHelpNote,
                    key: const ValueKey('name-note'),
                    style: ProfileText.fieldNote(
                      nameEmpty
                          ? AppColors.errorBannerBody
                          : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text('EMAIL', style: ProfileText.fieldLabel),
                  const SizedBox(height: 10),
                  // Read-only by design: a padlock, a muted fill, and no
                  // input at all — not a disabled TextField, which would
                  // still suggest it could become editable.
                  Container(
                    height: 56,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.cardTint,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.mail_outline,
                          size: 18,
                          color: AppColors.placeholder,
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Text(
                            widget.email,
                            overflow: TextOverflow.ellipsis,
                            style: ProfileText.fieldInput(
                              AppColors.textSecondary,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.lock_outline,
                          size: 16,
                          color: AppColors.textOnDisabled,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    kEmailLockedNote,
                    style: ProfileText.fieldNote(AppColors.placeholder),
                  ),
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
              onPressed: _canSave && !_saving ? _save : null,
            ),
          ),
        ],
        ),
      ),
    );
  }
}
