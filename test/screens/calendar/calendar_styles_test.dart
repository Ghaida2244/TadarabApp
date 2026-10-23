import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/screens/calendar/calendar_styles.dart';
import 'package:tadarab_app/theme/app_theme.dart';

void main() {
  group('hexFromColor', () {
    test('formats an opaque colour as 6 upper-case digits', () {
      expect(hexFromColor(const Color(0xFF2563EB)), '#2563EB');
    });

    test('always returns 7 characters, padding short values', () {
      // Black and near-black are where a naive radixString loses digits.
      expect(hexFromColor(const Color(0xFF000000)), '#000000');
      expect(hexFromColor(const Color(0xFF00000F)), '#00000F');
      expect(hexFromColor(const Color(0xFFFFFFFF)), '#FFFFFF');
    });

    test('drops alpha rather than carrying it into the hex', () {
      // The colour picker is configured with enableAlpha: false, but a
      // translucent value must still round-trip to the right RGB.
      expect(hexFromColor(const Color(0x802563EB)), '#2563EB');
      expect(hexFromColor(const Color(0x00FF0000)), '#FF0000');
    });

    test('round-trips through parseHexColor', () {
      for (final hex in kEventSwatchPool) {
        expect(hexFromColor(parseHexColor(hex)), hex.toUpperCase());
      }
    });

    test('round-trips an arbitrary picked colour', () {
      const picked = Color(0xFF7C3AED);
      expect(parseHexColor(hexFromColor(picked)), picked);
    });
  });
}
