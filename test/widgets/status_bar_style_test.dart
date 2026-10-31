import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tadarab_app/widgets/status_bar_style.dart';

void main() {
  group('statusBarStyleFor', () {
    test('always makes the status bar background transparent', () {
      expect(
        statusBarStyleFor(Colors.white).statusBarColor,
        Colors.transparent,
      );
      expect(
        statusBarStyleFor(const Color(0xFF0B0F5B)).statusBarColor,
        Colors.transparent,
      );
    });

    test('a very light background gets dark icons', () {
      final style = statusBarStyleFor(const Color(0xFFF7F8FD));
      expect(style.statusBarIconBrightness, Brightness.dark);
      expect(style.statusBarBrightness, Brightness.light);
    });

    test('white gets dark icons', () {
      final style = statusBarStyleFor(Colors.white);
      expect(style.statusBarIconBrightness, Brightness.dark);
      expect(style.statusBarBrightness, Brightness.light);
    });

    test('navy (the usual header colour) gets light icons', () {
      final style = statusBarStyleFor(const Color(0xFF0B0F5B));
      expect(style.statusBarIconBrightness, Brightness.light);
      expect(style.statusBarBrightness, Brightness.dark);
    });

    // All five kCoursePresetColors (lib/services/courses_service.dart) —
    // amber is the one exception: its luminance (~0.4645) sits above the
    // 0.4 threshold, so it gets dark icons while the other four (all well
    // under 0.4) get light icons.
    group('kCoursePresetColors', () {
      const lightIconColors = {
        'green': Color(0xFF16A34A),
        'blue': Color(0xFF2563EB),
        'red': Color(0xFFE31B23),
        'purple': Color(0xFF7C3AED),
      };

      for (final entry in lightIconColors.entries) {
        test('${entry.key} gets light icons (luminance well below 0.4)', () {
          final style = statusBarStyleFor(entry.value);
          expect(style.statusBarIconBrightness, Brightness.light);
          expect(style.statusBarBrightness, Brightness.dark);
        });
      }

      test(
        'amber gets dark icons (luminance ~0.4645, above the 0.4 '
        'threshold) — the one preset where the icon colour flips once the '
        'threshold moved from 0.5 to 0.4',
        () {
          final style = statusBarStyleFor(const Color(0xFFF5A524));
          expect(style.statusBarIconBrightness, Brightness.dark);
          expect(style.statusBarBrightness, Brightness.light);
        },
      );
    });

    // The rest of kEventSwatchPool (lib/screens/calendar/calendar_styles.dart)
    // not already covered by kCoursePresetColors above.
    group('kEventSwatchPool (remaining swatches)', () {
      const pool = {
        'teal': Color(0xFF0D9488),
        'pink': Color(0xFFDB2777),
        'orange': Color(0xFFEA580C),
        'sky': Color(0xFF0EA5E9),
        'lime': Color(0xFF65A30D),
        'fuchsia': Color(0xFFC026D3),
        'amber-brown': Color(0xFFB45309),
        'indigo': Color(0xFF4F46E5),
        'rose': Color(0xFFBE123C),
        'dark teal': Color(0xFF0F766E),
        'navy': Color(0xFF0B0F5B),
        'cyan': Color(0xFF0891B2),
      };

      for (final entry in pool.entries) {
        test('${entry.key} gets light icons', () {
          final style = statusBarStyleFor(entry.value);
          expect(style.statusBarIconBrightness, Brightness.light);
          expect(style.statusBarBrightness, Brightness.dark);
        });
      }
    });

    test(
      'the threshold is luminance > kStatusBarLuminanceThreshold (0.4), '
      'not a perceptual midpoint',
      () {
        expect(kStatusBarLuminanceThreshold, 0.4);
        // 0xAAAAAA has luminance ~0.402, just above 0.4 -> light (dark icons).
        final above = statusBarStyleFor(const Color(0xFFAAAAAA));
        expect(above.statusBarIconBrightness, Brightness.dark);
        // 0xA8A8A8 has luminance ~0.392, just below 0.4 -> dark (light icons).
        final below = statusBarStyleFor(const Color(0xFFA8A8A8));
        expect(below.statusBarIconBrightness, Brightness.light);
      },
    );
  });
}
