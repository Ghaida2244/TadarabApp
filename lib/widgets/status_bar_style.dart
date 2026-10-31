import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The luminance above which a header colour is treated as "light" (dark
/// icons). Lower than the perceptual midpoint (0.5) on purpose, so a medium
/// colour like amber (~0.4645) reads as light enough for dark icons even
/// though it's visually a fairly saturated colour, not a pale one.
const kStatusBarLuminanceThreshold = 0.4;

/// The status-bar style to use over a header painted [headerColor]: dark
/// icons on a light header, light icons on a dark one. "Light" means
/// [Color.computeLuminance] is above [kStatusBarLuminanceThreshold] — not a
/// perceptual "looks bright" judgement.
///
/// Always makes the status bar's own background transparent, so once a
/// header extends behind it, the header's own colour is what actually
/// shows through — not a separate OS-drawn scrim.
SystemUiOverlayStyle statusBarStyleFor(Color headerColor) {
  final isLight = headerColor.computeLuminance() > kStatusBarLuminanceThreshold;
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    // Android.
    statusBarIconBrightness: isLight ? Brightness.dark : Brightness.light,
    // iOS: Brightness.light means a light bar, so dark content on top of it.
    statusBarBrightness: isLight ? Brightness.light : Brightness.dark,
  );
}
