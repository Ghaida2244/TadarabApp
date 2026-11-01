import 'package:flutter/widgets.dart';

/// Wraps [child] — typically a whole screen's `Scaffold.body` — so tapping
/// any empty area of it dismisses the keyboard.
///
/// Used on every screen that also uses `keyboard_safe_padding.dart`'s
/// [EdgeInsets]: once the bottom action button there stops moving above
/// the keyboard (via `resizeToAvoidBottomInset: false`), nothing else on
/// screen moves either, so without this there would be no way left to
/// dismiss the keyboard other than finishing the field or backgrounding
/// the app.
///
/// `behavior: HitTestBehavior.opaque` is what makes this safe to wrap
/// around interactive content, in two ways:
///  - It's required at all for this to work on genuinely empty space
///    (gaps between fields, padding) — the default `deferToChild` only
///    counts as a hit where a descendant was *also* hit, so without it a
///    tap on truly empty space would never reach this [onTap] in the
///    first place.
///  - It still lets the tap reach a real descendant control underneath —
///    a button, chip, date-picker field or text field each has its own
///    recognizer, which wins the gesture arena for that pointer over this
///    wrapper's, so tapping one of those fires *only* that control's own
///    handler, never this [onTap] as well. This only ever fires for a tap
///    that nothing else already responded to.
class DismissKeyboardOnTap extends StatelessWidget {
  const DismissKeyboardOnTap({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: child,
    );
  }
}
