import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../profile_styles.dart';

/// The navy header the Profile tab shows: a generic avatar glyph, the
/// student's name, and an edit chip in the top-right corner.
///
/// The avatar is a glyph only — `Student` has no photo field and the design
/// offers no upload affordance.
class ProfileAvatarHeader extends StatelessWidget {
  const ProfileAvatarHeader({
    super.key,
    required this.name,
    required this.onEdit,
  });

  /// The student's name. Empty while the document is still loading.
  final String name;

  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
      child: SafeArea(
        bottom: false,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            Column(
              children: [
                const SizedBox(height: 16),
                Container(
                  width: 74,
                  height: 74,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_outline,
                    size: 36,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  name,
                  textAlign: TextAlign.center,
                  style: ProfileText.profileName,
                ),
              ],
            ),
            Positioned(
              top: 16,
              right: 0,
              child: Semantics(
                button: true,
                label: 'Edit profile',
                child: GestureDetector(
                  onTap: onEdit,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.edit_outlined,
                      size: 17,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The white card every Profile row and panel sits on: the design's
/// `0 0 0 2px #EEF0FF` ring plus a hard `0 3px 0` drop.
class ProfileCard extends StatelessWidget {
  const ProfileCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 20,
    this.color = Colors.white,
  });

  final Widget child;
  final EdgeInsets padding;
  final double borderRadius;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          const BoxShadow(color: AppColors.cardTint, spreadRadius: 2),
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.07),
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}
