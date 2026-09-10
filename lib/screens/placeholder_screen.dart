import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A bare "not built yet" screen: centered label, nothing else. Used for
/// the Courses/Calendar/Profile bottom-nav tabs and the Quiz/Flashcard
/// setup screens — all Phase C work not built yet — so navigating to them
/// shows something deliberate instead of erroring or dead-ending.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.label, this.actions});

  final String label;

  /// Extra widgets shown below the label — e.g. a sign-out button on the
  /// Profile placeholder, since there's nowhere else for it to live yet.
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: AppTypography.screenTitleCompact),
            if (actions != null) ...[const SizedBox(height: 20), ...actions!],
          ],
        ),
      ),
    );
  }
}
