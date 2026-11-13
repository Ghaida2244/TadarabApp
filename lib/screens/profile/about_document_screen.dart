import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';
import '../../widgets/screen_header.dart';
import '../../widgets/status_bar_style.dart';
import 'content/about_content.dart';
import 'profile_styles.dart';
import 'widgets/profile_header.dart';

/// Renders one of the plain About documents — About Us, Privacy Policy or
/// Terms of Use — as the design's "classic" stack of headed cards.
///
/// The Learning Guide uses its own richer screen instead; see
/// `learning_guide_screen.dart`.
class AboutDocumentScreen extends StatelessWidget {
  const AboutDocumentScreen({super.key, required this.document});

  final AboutDocument document;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: statusBarStyleFor(AppColors.navy),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          children: [
            ScreenHeader(
              title: document.title,
              backgroundColor: AppColors.navy,
              icon: Icons.chevron_left,
              semanticLabel: 'Back',
              buttonOnStart: true,
              onClose: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
                itemCount: document.blocks.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final block = document.blocks[index];
                  return ProfileCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(block.heading, style: ProfileText.docHeading),
                        const SizedBox(height: 9),
                        Text(block.body, style: ProfileText.docBody),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
