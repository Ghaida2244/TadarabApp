import 'package:flutter/material.dart';

/// A full-bleed coloured screen header: a title (with an optional subtitle),
/// and a circular icon button — a close "×" at the end (the default; see
/// [icon]) or a back chevron at the start (see [buttonOnStart]). Shared by
/// Add course and Add Event (close, at the end) and by every Profile
/// sub-screen — Ranks, Edit Profile, the About documents, the Learning
/// Guide and Study Reminder (back, at the start) — so none of them can
/// drift apart.
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
    this.icon = Icons.close,
    this.semanticLabel = 'Close',
    this.buttonOnStart = false,
  });

  final String title;

  /// Shown under [title] in a dimmer style, when given.
  final String? subtitle;

  final Color backgroundColor;

  /// Null disables the close action and dims its icon — e.g. while a save
  /// started from this screen is in flight.
  final VoidCallback? onClose;

  /// The icon in the circular button on the right. Defaults to a close
  /// "×", matching Add course/Add Event. A screen that's popped back to
  /// rather than closed (e.g. Profile's Ranks/Edit Profile/About
  /// documents) passes [Icons.chevron_left] instead, pairing it with
  /// [semanticLabel].
  final IconData icon;

  /// The accessibility label for the circular button. Defaults to
  /// 'Close', matching [icon]'s default — override together with [icon]
  /// (e.g. 'Back' for a back chevron) so the two stay in sync.
  final String semanticLabel;

  /// False (the default, matching Add course/Add Event's close "×") puts
  /// the button at the *end* of the header, after the title. True (for a
  /// back chevron, e.g. Profile's screens) puts it at the *start*,
  /// before the title — like the old `ProfileSubHeader` did.
  ///
  /// "Start"/"end", not "left"/"right": the button is simply the Row's
  /// first or last child, so [Directionality] (inherited the normal way,
  /// not read explicitly here) places it correctly in an RTL layout too,
  /// exactly as `ProfileSubHeader` relied on the same Row behaviour
  /// rather than hardcoding a side.
  final bool buttonOnStart;

  @override
  Widget build(BuildContext context) {
    final enabled = onClose != null;

    final titleColumn = Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // FittedBox + scaleDown + maxLines: 1: a title that already fits
          // (every current title except 'Privacy Policy'/'Learning Guide'
          // at a phone-width screen) is rendered at exactly its natural
          // size — scaleDown never grows a child, only shrinks one that's
          // too big for the space it's given — so Add course/Add Event's
          // own headers are pixel-identical to before. A title that
          // doesn't fit shrinks as a whole, single-line block instead of
          // wrapping to a second line (which would make the header taller
          // than the other screens') or silently truncating with an
          // ellipsis.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              title,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.02 * 26,
                color: Colors.white,
              ),
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
    );

    final button = Semantics(
      button: true,
      label: semanticLabel,
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
            icon,
            size: 18,
            color: Colors.white.withValues(alpha: enabled ? 1 : 0.4),
          ),
        ),
      ),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        // The button is simply the Row's first or last child — Row lays
        // children out start-to-end per the ambient Directionality, so
        // this places the button correctly in an RTL layout too, with no
        // explicit left/right check needed (matching how the old
        // ProfileSubHeader put its own back chip first in an otherwise
        // identical Row).
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: buttonOnStart
              ? [button, const SizedBox(width: 13), titleColumn]
              : [titleColumn, button],
        ),
      ),
    );
  }
}
