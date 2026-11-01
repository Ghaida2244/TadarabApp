import 'package:flutter/widgets.dart';

/// [base] with the keyboard's current height added to its bottom.
///
/// For a screen shaped as `Scaffold(resizeToAvoidBottomInset: false, body:
/// Column([header, Expanded(SingleChildScrollView(...)), fixedFooter]))` —
/// a scrollable form above a footer button that must stay pinned at the
/// true bottom of the screen, covered by the keyboard rather than pushed
/// above it. `resizeToAvoidBottomInset: false` stops the Scaffold (and so
/// the footer) from moving, but it also stops the scroll view's own
/// viewport from shrinking for the keyboard — so without this, the last
/// field in the form could end up permanently hidden behind it. Passing
/// this as the scroll view's `padding` restores that room: the scrollable
/// area gains exactly the keyboard's height as extra bottom padding while
/// it's open, so every field — including the last one — can still be
/// scrolled clear of it, and `Scrollable.ensureVisible` (which `EditableText`
/// already calls when a field gains focus) correctly scrolls a
/// newly-focused field above the keyboard instead of treating the covered
/// area as still visible.
EdgeInsets keyboardSafePadding(BuildContext context, EdgeInsets base) {
  return base + EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom);
}
