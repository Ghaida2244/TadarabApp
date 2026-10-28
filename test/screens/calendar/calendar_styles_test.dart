import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/screens/calendar/calendar_styles.dart';
import 'package:tadarab_app/services/courses_service.dart';
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

  group('defaultEventColor', () {
    test('is green when no course uses it', () {
      expect(defaultEventColor(const []), '#16A34A');
    });

    test('falls back to amber once a course uses green', () {
      expect(defaultEventColor(const ['#16A34A']), '#F5A524');
    });

    test('matches course colours case-insensitively', () {
      expect(defaultEventColor(const ['#16a34a']), '#F5A524');
    });

    test(
      'falls back to the next free pool colour once green and amber are '
      'both taken',
      () {
        expect(
          defaultEventColor(const ['#16A34A', '#F5A524']),
          '#2563EB', // the pool's own next entry, in its own order
        );
      },
    );

    test('falls back to the pool\'s first colour once every colour is taken', () {
      expect(defaultEventColor(kEventSwatchPool), kEventSwatchPool.first);
    });
  });

  group('randomEventColor', () {
    // Every kEventSwatchPool entry that isn't one of the 5 presets — 12 of
    // them, with the pool at its current 17-colour length.
    const nonPresetPool = [
      '#0D9488',
      '#DB2777',
      '#EA580C',
      '#0EA5E9',
      '#65A30D',
      '#C026D3',
      '#B45309',
      '#4F46E5',
      '#BE123C',
      '#0F766E',
      '#0B0F5B',
      '#0891B2',
    ];

    test(
      'the pick is outside the five presets, not a course colour and not '
      'a standalone colour',
      () {
        final pick = randomEventColor(
          courseColors: const ['#16A34A', '#0D9488'],
          standaloneColors: const ['#DB2777', '#EA580C'],
          random: Random(1),
        );

        expect(kCoursePresetColors, isNot(contains(pick)));
        expect(pick, isNot('#16A34A'));
        expect(pick, isNot('#0D9488'));
        expect(pick, isNot('#DB2777'));
        expect(pick, isNot('#EA580C'));
        expect(kEventSwatchPool, contains(pick));
      },
    );

    test('a seeded Random gives a stable, repeatable result', () {
      final first = randomEventColor(
        courseColors: const [],
        standaloneColors: const [],
        random: Random(42),
      );
      final second = randomEventColor(
        courseColors: const [],
        standaloneColors: const [],
        random: Random(42),
      );

      expect(first, second);
    });

    test('with no exclusions, the pick is always one of the non-preset pool entries', () {
      for (var seed = 0; seed < 20; seed++) {
        final pick = randomEventColor(
          courseColors: const [],
          standaloneColors: const [],
          random: Random(seed),
        );
        expect(nonPresetPool, contains(pick));
      }
    });

    test(
      'fallback 1: once standalone colours cover every non-preset, '
      'non-course entry, a standalone colour is allowed back in',
      () {
        final pick = randomEventColor(
          courseColors: const [],
          standaloneColors: nonPresetPool,
          random: Random(1),
        );

        expect(nonPresetPool, contains(pick));
        expect(kCoursePresetColors, isNot(contains(pick)));
      },
    );

    test(
      'fallback 2: once courses cover every non-preset entry too, a '
      'preset is allowed back in',
      () {
        final pick = randomEventColor(
          courseColors: nonPresetPool,
          standaloneColors: const [],
          random: Random(1),
        );

        expect(kCoursePresetColors, contains(pick));
      },
    );

    test(
      'fallback 3: once the whole pool is taken by courses, '
      "kEventSwatchPool.first is returned regardless",
      () {
        final pick = randomEventColor(
          courseColors: kEventSwatchPool,
          standaloneColors: const [],
          random: Random(1),
        );

        expect(pick, kEventSwatchPool.first);
      },
    );

    test('matches course and standalone colours case-insensitively', () {
      // Every pool entry except one, all lower-case — the single
      // remaining upper-case entry should still be the only candidate.
      final allButOne = kEventSwatchPool
          .where((h) => h != kEventSwatchPool.last)
          .map((h) => h.toLowerCase())
          .toList();

      final pick = randomEventColor(
        courseColors: allButOne,
        standaloneColors: const [],
        random: Random(1),
      );

      expect(pick, kEventSwatchPool.last);
    });
  });

  group('eventColorTiles', () {
    test('lists the saved colours, in order, each marked removable', () {
      final tiles = eventColorTiles(
        savedColors: const ['#2563EB', '#7C3AED'],
        courseColors: const [],
      );

      expect(tiles, [
        const EventColorTile('#2563EB', removable: true),
        const EventColorTile('#7C3AED', removable: true),
      ]);
    });

    test('is empty when there are no saved colours and nothing selected', () {
      final tiles = eventColorTiles(
        savedColors: const [],
        courseColors: const [],
      );

      expect(tiles, isEmpty);
    });

    test(
      'drops any saved colour a course uses, from the display — not from '
      'the list itself, which this function never sees as persisted state',
      () {
        final tiles = eventColorTiles(
          savedColors: const ['#16A34A', '#2563EB', '#7C3AED'],
          courseColors: const ['#16A34A', '#7C3AED'],
        );

        expect(tiles, [const EventColorTile('#2563EB', removable: true)]);
      },
    );

    test('matches course colours case-insensitively', () {
      final tiles = eventColorTiles(
        savedColors: const ['#16a34a'],
        courseColors: const ['#16A34A'],
      );

      expect(tiles, isEmpty);
    });

    test(
      'the current selection shows as the extra, non-removable tile '
      'alongside the recents — the default appears this way too, since '
      'it\'s passed in as selectedColor',
      () {
        final tiles = eventColorTiles(
          savedColors: const ['#2563EB'],
          courseColors: const [],
          selectedColor: '#FF00A8',
        );

        expect(tiles, [
          const EventColorTile('#2563EB', removable: true),
          const EventColorTile('#FF00A8'),
        ]);
      },
    );

    test('does not duplicate the selected colour when it is already a tile', () {
      final tiles = eventColorTiles(
        savedColors: const ['#2563EB'],
        courseColors: const [],
        selectedColor: '#2563EB',
      );

      expect(tiles, [const EventColorTile('#2563EB', removable: true)]);
    });

    test(
      'the selected colour alone, with no saved colours, is still the one '
      'tile shown — the row is never just "+" with nothing selected',
      () {
        final tiles = eventColorTiles(
          savedColors: const [],
          courseColors: const [],
          selectedColor: '#16A34A',
        );

        expect(tiles, [const EventColorTile('#16A34A')]);
      },
    );

    test(
      'never drops the selected colour for being a course colour — only '
      'the saved list is filtered that way',
      () {
        final tiles = eventColorTiles(
          savedColors: const [],
          courseColors: const ['#FF00A8'],
          selectedColor: '#FF00A8',
        );

        expect(tiles, [const EventColorTile('#FF00A8')]);
      },
    );

    test('a null selected colour adds no extra tile', () {
      final tiles = eventColorTiles(
        savedColors: const [],
        courseColors: const [],
      );

      expect(tiles, isEmpty);
    });
  });
}
