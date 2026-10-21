import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

const _kPillHPadding = 11.0;
const _kPillVPadding = 6.0;

/// A pill that hugs [text] up to the full width its parent offers; if the
/// text is still too wide even at that full width, it becomes exactly that
/// width and the text scrolls horizontally inside it by drag (a plain
/// `SingleChildScrollView`, not auto-animating) — never wraps to a second
/// line or truncates with an ellipsis.
///
/// Extracted from the Flashcard Sessions screen's own material-title pill
/// (NOTE 12) so the Quiz Sessions screen's materials bar can match it
/// exactly rather than maintaining a second, drifting implementation —
/// both screens build the same thing.
///
/// The "available width" is read from an invisible, full-width sizing box
/// via a `GlobalKey` + `RenderBox` in a post-frame callback, not a
/// `LayoutBuilder`: a session card's colored side-strip needs
/// `IntrinsicHeight`, and a `LayoutBuilder` inside an intrinsic-sizing pass
/// throws a storm of `RenderFlex`/`debugCheckForParentData` assertions and
/// hangs `pumpAndSettle` — a failure hit and fixed here before. Reading a
/// `RenderBox` after layout has already finished sidesteps that class of
/// bug entirely: the first frame always renders the plain, intrinsically-
/// safe hugging layout, and only a later frame may switch to the
/// fixed-width scrolling one.
class ScrollableTitlePill extends StatefulWidget {
  const ScrollableTitlePill({super.key, required this.text, required this.style});

  final String text;
  final TextStyle style;

  @override
  State<ScrollableTitlePill> createState() => _ScrollableTitlePillState();
}

class _ScrollableTitlePillState extends State<ScrollableTitlePill> {
  final _measureKey = GlobalKey();

  late double _textWidth;
  double? _availableWidth;

  double _measure() {
    final painter = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      textDirection: TextDirection.ltr,
    )..layout();
    return painter.width;
  }

  @override
  void initState() {
    super.initState();
    _textWidth = _measure();
    WidgetsBinding.instance.addPostFrameCallback(_checkAvailableWidth);
  }

  // A caller whose text resolves asynchronously (e.g. Quiz Sessions' own
  // materials map, fetched separately from the session itself, unlike
  // Flashcards' `materialTitles` which is already a field on the session
  // document) rebuilds this same widget with a *different* `text` once
  // that data arrives. `_textWidth` was originally a `late final` —
  // computed once, on first access, and never recalculated — so for a
  // caller like that it would permanently measure whatever placeholder
  // text happened to be showing at the very first build, never the real
  // label. Recomputing it here whenever `text`/`style` actually change
  // fixes that for good, not just for Quiz's specific case.
  @override
  void didUpdateWidget(covariant ScrollableTitlePill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != oldWidget.text || widget.style != oldWidget.style) {
      _textWidth = _measure();
    }
  }

  void _checkAvailableWidth(Duration _) {
    if (!mounted) return;
    final box = _measureKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    if (_availableWidth != box.size.width) {
      setState(() => _availableWidth = box.size.width);
    }
  }

  @override
  Widget build(BuildContext context) {
    final contentWidth = _textWidth + _kPillHPadding * 2;
    final needsScroll =
        _availableWidth != null && contentWidth > _availableWidth!;

    final text = Text(
      widget.text,
      style: widget.style,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.clip,
    );

    final pill = Container(
      width: needsScroll ? _availableWidth : null,
      padding: const EdgeInsets.symmetric(
        horizontal: _kPillHPadding,
        vertical: _kPillVPadding,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardTint,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: needsScroll
          ? SingleChildScrollView(scrollDirection: Axis.horizontal, child: text)
          : text,
    );

    // The measuring box spans the full width offered by the parent Column
    // (invisible — no decoration of its own) so a later frame can learn
    // the true available width; the visible pill inside it still hugs its
    // own content via Align, which doesn't force its child to fill.
    return SizedBox(
      key: _measureKey,
      width: double.infinity,
      child: Align(alignment: Alignment.centerLeft, child: pill),
    );
  }
}
