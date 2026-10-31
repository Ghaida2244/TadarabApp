import 'package:flutter/material.dart';

/// A full-bleed coloured screen header: a title (with an optional subtitle)
/// on the left, and a circular close "×" button on the right. Shared by Add
/// course and Add Event so the two can't drift apart.
///
/// Extends behind the status bar: its own [SafeArea] (bottom: false) gives
/// just the header's content room below the status-bar inset, rather than
/// the caller wrapping its whole body in one and pushing the header's
/// background down too.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    required this.backgroundColor,
    required this.onClose,
  });

  final String title;

  /// Shown under [title] in a dimmer style, when given.
  final String? subtitle;

  final Color backgroundColor;

  /// Null disables the close action and dims its icon — e.g. while a save
  /// started from this screen is in flight.
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final enabled = onClose != null;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.02 * 26,
                      color: Colors.white,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xB3FFFFFF),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Semantics(
              button: true,
              label: 'Close',
              child: GestureDetector(
                onTap: onClose,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Color(0x29FFFFFF),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close,
                    size: 18,
                    color: Colors.white.withValues(alpha: enabled ? 1 : 0.4),
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
