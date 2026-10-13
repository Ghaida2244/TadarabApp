import 'package:flutter/material.dart';

/// A `ScrollBehavior` that never draws a scrollbar — used so the drag-
/// scroll area never shows one, regardless of platform defaults.
class _NoScrollbarBehavior extends ScrollBehavior {
  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}

/// Text that scrolls horizontally via a normal, user-driven drag when it's
/// wider than the space it's given — no automatic movement, no `Timer`, no
/// `AnimationController`. When the text already fits, it's fully static:
/// no scroll view is introduced at all, and nothing listens for scroll
/// events.
///
/// Reuses the same measurement technique as `ScrollableTitlePill` (a
/// `GlobalKey` + `RenderBox` read in a post-frame callback, not a
/// `LayoutBuilder`) — not the widget itself, since `ScrollableTitlePill`
/// also imposes its own pill container (background/padding/radius), which
/// would change the look of all three real callers here. This widget adds
/// no container of its own; callers keep their existing chip styling
/// untouched and just drop this in for the text line.
///
/// `LayoutBuilder` is avoided because this widget's real callers all sit
/// inside a `Column` with no fixed height, and a `LayoutBuilder` placed
/// inside such an unbounded-height ancestor throws under the
/// `IntrinsicHeight`-style dry-layout queries used elsewhere in this app
/// (see `ScrollableTitlePill`'s own doc comment for the concrete failure
/// this avoids).
class DraggableOverflowText extends StatefulWidget {
  const DraggableOverflowText({
    super.key,
    required this.text,
    required this.style,
    required this.fadeColor,
  });

  final String text;
  final TextStyle style;

  /// The color the trailing-edge "more to scroll" hint fades *into* —
  /// should match the chip's own background so the gradient reads as a
  /// soft edge, not a visible seam against it.
  final Color fadeColor;

  @override
  State<DraggableOverflowText> createState() => _DraggableOverflowTextState();
}

class _DraggableOverflowTextState extends State<DraggableOverflowText> {
  final _measureKey = GlobalKey();
  final _scrollController = ScrollController();

  late double _textWidth;
  double? _availableWidth;
  bool _hasMoreToScroll = false;

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
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback(_checkAvailableWidth);
  }

  // Same fix as ScrollableTitlePill's own didUpdateWidget: a caller whose
  // text resolves or changes after the first build (the Quiz chips'
  // sourceLocation can arrive from an async fetch) must have this
  // re-measured, not keep using a cached measurement of stale text.
  @override
  void didUpdateWidget(covariant DraggableOverflowText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != oldWidget.text || widget.style != oldWidget.style) {
      _textWidth = _measure();
      WidgetsBinding.instance.addPostFrameCallback(_checkAvailableWidth);
    }
  }

  void _checkAvailableWidth(Duration _) {
    if (!mounted) return;
    final box = _measureKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final width = box.size.width;
    if (_availableWidth == width) return;
    setState(() {
      _availableWidth = width;
      // True from the very start whenever there's real overflow — the
      // scroll position is always 0 at this point, so there's always
      // more ahead; the listener below takes over once the user drags.
      _hasMoreToScroll = _textWidth > width;
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final hasMore = position.pixels < position.maxScrollExtent - 0.5;
    if (hasMore != _hasMoreToScroll) {
      setState(() => _hasMoreToScroll = hasMore);
    }
  }

  bool get _needsScroll => _availableWidth != null && _textWidth > _availableWidth!;

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Text(
      widget.text,
      style: widget.style,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.clip,
    );

    final needsScroll = _needsScroll;

    final content = needsScroll
        ? Stack(
            alignment: Alignment.centerRight,
            children: [
              ScrollConfiguration(
                behavior: _NoScrollbarBehavior(),
                child: SingleChildScrollView(
                  key: const ValueKey('draggable-overflow-scroll'),
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  // Default (platform) physics — a normal finger drag,
                  // nothing custom.
                  child: text,
                ),
              ),
              if (_hasMoreToScroll)
                IgnorePointer(
                  key: const ValueKey('draggable-overflow-fade'),
                  child: Container(
                    width: 20,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          widget.fadeColor.withValues(alpha: 0),
                          widget.fadeColor,
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          )
        : text;

    return SizedBox(key: _measureKey, width: double.infinity, child: content);
  }
}
