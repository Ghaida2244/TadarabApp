import 'package:flutter/material.dart';

/// The translucent-white-on-color circular icon button used on every
/// navy/red header in the Flashcards design handoff (back/close buttons).
class HeaderCircleButton extends StatelessWidget {
  const HeaderCircleButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 38,
    this.iconSize = 19,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: iconSize, color: Colors.white),
      ),
    );
  }
}
