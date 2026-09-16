import 'package:flutter/material.dart';

import 'app_colors.dart';

export 'app_colors.dart';
export 'app_spacing.dart';
export 'app_typography.dart';

/// Assembles the Tadarab design system into a [ThemeData] for [MaterialApp].
/// Buttons and text fields are custom widgets (see lib/widgets/) rather than
/// themed Material ones, since the design's hard-offset button shadows and
/// bordered fields don't map onto Material's defaults — but everything still
/// draws its colors and type from [AppColors]/[AppTypography].
class AppTheme {
  AppTheme._();

  /// The one font family name, bundled via pubspec (see `fonts:` there).
  static const String fontFamily = 'Nunito';

  static ThemeData get themeData {
    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.navy,
        primary: AppColors.navy,
        error: AppColors.error,
      ),
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: fontFamily,
      useMaterial3: true,
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(fontFamily: fontFamily),
      splashFactory: NoSplash.splashFactory,
    );
  }
}
