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

  group('initialEventColor', () {
    test('is the first saved colour that is not a course colour', () {
      expect(
        initialEventColor(
          savedColors: const ['#2563EB', '#7C3AED'],
          courseColors: const [],
        ),
        '#2563EB',
      );
    });

    test('skips a saved colour a course now uses', () {
      expect(
        initialEventColor(
          savedColors: const ['#2563EB', '#7C3AED'],
          courseColors: const ['#2563EB'],
        ),
        '#7C3AED',
      );
    });

    test('matches course colours case-insensitively', () {
      expect(
        initialEventColor(
          savedColors: const ['#2563EB'],
          courseColors: const ['#2563eb'],
        ),
        '#16A34A', // falls through to defaultEventColor
      );
    });

    test('falls back to defaultEventColor when the saved list is empty', () {
      expect(
        initialEventColor(savedColors: const [], courseColors: const []),
        '#16A34A',
      );
    });

    test(
      'falls back to defaultEventColor when every saved colour is now a '
      'course\'s',
      () {
        expect(
          initialEventColor(
            savedColors: const ['#16A34A'],
            courseColors: const ['#16A34A'],
          ),
          '#F5A524',
        );
      },
    );
  });

  group('eventColorTiles', () {
    test('lists the saved colours, in order, each marked removable', () {
      final tiles = eventColorTiles(
        defaultColor: '#16A34A',
        savedColors: const ['#2563EB', '#7C3AED'],
        courseColors: const [],
      );

      expect(tiles, [
        const EventColorTile('#2563EB', removable: true),
        const EventColorTile('#7C3AED', removable: true),
      ]);
    });

    test(
      'shows the non-removable default tile alone when the saved list is '
      'empty',
      () {
        final tiles = eventColorTiles(
          defaultColor: '#16A34A',
          savedColors: const [],
          courseColors: const [],
        );

        expect(tiles, [const EventColorTile('#16A34A')]);
      },
    );

    test(
      'drops any saved colour a course uses, from the display — not from '
      'the list itself, which this function never sees as persisted state',
      () {
        final tiles = eventColorTiles(
          defaultColor: '#16A34A',
          savedColors: const ['#16A34A', '#2563EB', '#7C3AED'],
          courseColors: const ['#16A34A', '#7C3AED'],
        );

        expect(tiles, [const EventColorTile('#2563EB', removable: true)]);
      },
    );

    test('matches course colours case-insensitively', () {
      final tiles = eventColorTiles(
        defaultColor: '#16A34A',
        savedColors: const ['#16a34a'],
        courseColors: const ['#16A34A'],
      );

      // Every saved colour was filtered out, so the empty-list default
      // tile shows instead — and it's filtered too, since green is a
      // course colour, leaving no tiles at all here.
      expect(tiles, isEmpty);
    });

    test(
      'falls back to the non-removable default tile once every saved '
      'colour is filtered out by a course',
      () {
        final tiles = eventColorTiles(
          defaultColor: '#F5A524',
          savedColors: const ['#16A34A'],
          courseColors: const ['#16A34A'],
        );

        expect(tiles, [const EventColorTile('#F5A524')]);
      },
    );

    test(
      'adds an extra, non-removable tile for the selected colour when it '
      'is not already covered',
      () {
        final tiles = eventColorTiles(
          defaultColor: '#16A34A',
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
        defaultColor: '#16A34A',
        savedColors: const ['#2563EB'],
        courseColors: const [],
        selectedColor: '#2563EB',
      );

      expect(tiles, [const EventColorTile('#2563EB', removable: true)]);
    });

    test(
      'never drops the selected colour for being a course colour — only '
      'the saved list and the empty-list default are filtered that way',
      () {
        final tiles = eventColorTiles(
          defaultColor: '#16A34A',
          savedColors: const [],
          courseColors: const ['#FF00A8'],
          selectedColor: '#FF00A8',
        );

        expect(tiles, [
          const EventColorTile('#16A34A'),
          const EventColorTile('#FF00A8'),
        ]);
      },
    );

    test('a null selected colour adds no extra tile', () {
      final tiles = eventColorTiles(
        defaultColor: '#16A34A',
        savedColors: const [],
        courseColors: const [],
      );

      expect(tiles, [const EventColorTile('#16A34A')]);
    });
  });
}
