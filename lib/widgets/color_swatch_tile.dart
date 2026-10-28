import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// One rounded-square colour option in a colour-picking grid: Add course's
/// preset swatches and Add Event's default/recent/selected tiles both use
/// this, so the two screens' grids look and behave identically.
///
/// Shows a check when [selected], or — while [locked] — a dimmed tile with
/// a lock "×" instead, since a colour already claimed elsewhere can't be
/// picked (Add course's current "another course already has this colour"
/// rule; [locked] simply defaults to false for a feature with no such
/// concept, like Add Event).
///
/// [onRemove], when given, draws a small always-visible "×" badge on the
/// tile's top corner with its own, larger invisible tap area — Add Event's
/// way of letting a student drop one of her saved quick-colours. Add
/// course never passes it, so its tiles are unaffected.
class ColorSwatchTile extends StatelessWidget {
  const ColorSwatchTile({
    super.key,
    required this.color,
    required this.hex,
    required this.selected,
    this.locked = false,
    required this.onTap,
    this.onRemove,
  });

  /// The swatch's fill.
  final Color color;

  /// The same colour as a "#RRGGBB" string, for its accessibility label —
  /// kept separate from [color] rather than derived from it, since both
  /// callers already have the hex on hand and formatting it back out of a
  /// [Color] is a feature-level concern ([hexFromColor] lives with the
  /// Calendar's other colour helpers, not in this shared widgets folder).
  final String hex;

  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  /// Called when the remove badge is tapped. Null hides the badge entirely.
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Color $hex',
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            onTap: locked ? null : onTap,
            child: Opacity(
              opacity: locked ? 0.3 : 1,
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: selected ? AppColors.navy : Colors.transparent,
                    width: 3,
                  ),
                  boxShadow: locked
                      ? null
                      : [
                          BoxShadow(
                            color: AppColors.navy.withValues(alpha: 0.15),
                            offset: const Offset(0, 4),
                          ),
                        ],
                ),
                child: Icon(
                  selected
                      ? Icons.check
                      : locked
                      ? Icons.close
                      : null,
                  size: 18,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          if (onRemove != null) _RemoveBadge(hex: hex, onRemove: onRemove!),
        ],
      ),
    );
  }
}

/// The small "×" a removable [ColorSwatchTile] shows at its top-right
/// corner. Its drawn circle is 16px, but its tap area is a full 26px —
/// easy to hit without stealing taps from the rest of the tile.
class _RemoveBadge extends StatelessWidget {
  const _RemoveBadge({required this.hex, required this.onRemove});

  final String hex;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: -6,
      right: -6,
      child: Semantics(
        button: true,
        label: 'Remove color $hex',
        child: GestureDetector(
          onTap: onRemove,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            color: Colors.transparent,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: AppColors.navy.withValues(alpha: 0.55),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: const Icon(Icons.close, size: 10, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

/// The rainbow-gradient "+" tile that opens a full colour picker, in the
/// same grid as [ColorSwatchTile].
class CustomColorSwatchTile extends StatelessWidget {
  const CustomColorSwatchTile({
    super.key,
    required this.selected,
    required this.onTap,
  });

  /// True once the currently-picked colour isn't one of the grid's other
  /// (preset/default/recent) tiles — i.e. it came from this tile's own
  /// dialog.
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Custom color',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? AppColors.navy : Colors.transparent,
              width: 3,
            ),
            gradient: const SweepGradient(
              colors: [
                Color(0xFFFF0000),
                Color(0xFFFFD400),
                Color(0xFF38D200),
                Color(0xFF00D4C8),
                Color(0xFF0066FF),
                Color(0xFF8A00E6),
                Color(0xFFFF00A8),
                Color(0xFFFF0000),
              ],
            ),
          ),
          child: Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.92),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.add, size: 16, color: AppColors.navy),
          ),
        ),
      ),
    );
  }
}
