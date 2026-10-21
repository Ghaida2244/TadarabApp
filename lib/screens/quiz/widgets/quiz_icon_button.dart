import 'package:flutter/material.dart';

/// The circular translucent-white icon button used on every Quiz navy
/// header — back arrow (Sessions/Setup/Review Mistakes) or close/X (Exam's
/// absence, Learning mode's exit). `rgba(255,255,255,0.2)` background per
/// the design, white icon.
class QuizIconButton extends StatelessWidget {
  const QuizIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 38,
    this.semanticLabel,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: size * 0.5, color: Colors.white),
        ),
      ),
    );
  }
}
