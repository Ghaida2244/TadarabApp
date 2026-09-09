/// Spacing and radius scale, matching the gap/padding/radius values used
/// throughout the Phase 0/1 design handoffs.
class AppSpacing {
  AppSpacing._();

  static const double xs = 7;
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 26;
  static const double xxxl = 40;
}

/// Corner radii used across cards, buttons and fields.
class AppRadius {
  AppRadius._();

  /// Buttons, cards, the error/confirmation banners.
  static const double lg = 16;

  /// Text fields.
  static const double md = 14;

  /// Fully round (avatars, the circular back-button chip, pill badges).
  static const double pill = 999;
}

/// Fixed control heights used across the auth screens.
class AppDimens {
  AppDimens._();

  /// Standard text field height.
  static const double fieldHeight = 54;

  /// Primary/accent button height.
  static const double buttonHeight = 56;

  /// Secondary (outlined) button height.
  static const double secondaryButtonHeight = 52;

  /// The circular back-button chip.
  static const double backButtonSize = 40;
}
