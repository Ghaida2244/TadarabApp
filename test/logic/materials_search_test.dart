import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/logic/materials_search.dart';
import 'package:tadarab_app/models/study_material.dart';

StudyMaterial _material({
  required String id,
  required String title,
  DateTime? createdAt,
}) {
  return StudyMaterial(
    materialId: id,
    title: title,
    type: 'txt',
    document: 'd/$id',
    courseId: 'c1',
    extractedText: '[Paragraph 1]\nSome text.',
    createdAt: createdAt,
  );
}

void main() {
  group('filterMaterialsByQuery', () {
    final materials = [
      _material(id: '1', title: 'Lecture 1 — Introduction'),
      _material(id: '2', title: 'Diagram notes'),
      _material(id: '3', title: 'LECTURE 2 — Requirements'),
    ];

    test('normal: a case-insensitive substring match narrows the list', () {
      final result = filterMaterialsByQuery(materials, 'lecture');
      expect(result.map((m) => m.materialId), ['1', '3']);
    });

    test('edge: surrounding whitespace in the query is trimmed', () {
      final result = filterMaterialsByQuery(materials, '  lecture  ');
      expect(result.map((m) => m.materialId), ['1', '3']);
    });

    test('edge: a blank query returns every material, not none', () {
      expect(filterMaterialsByQuery(materials, '   '), materials);
    });

    test('failure: no title matches the query', () {
      expect(filterMaterialsByQuery(materials, 'midterm'), isEmpty);
    });
  });

  group('sortMaterials newestFirst/oldestFirst', () {
    final older = _material(
      id: 'older',
      title: 'B',
      createdAt: DateTime(2026, 1, 1),
    );
    final newer = _material(
      id: 'newer',
      title: 'A',
      createdAt: DateTime(2026, 2, 1),
    );
    final undatedA = _material(id: 'undatedA', title: 'A undated');
    final undatedB = _material(id: 'undatedB', title: 'B undated');

    test('normal: newestFirst orders dated materials by createdAt '
        'descending', () {
      final result = sortMaterials(
        [older, newer],
        MaterialSortOrder.newestFirst,
      );
      expect(result.map((m) => m.materialId), ['newer', 'older']);
    });

    test('normal: oldestFirst orders dated materials by createdAt '
        'ascending', () {
      final result = sortMaterials(
        [newer, older],
        MaterialSortOrder.oldestFirst,
      );
      expect(result.map((m) => m.materialId), ['older', 'newer']);
    });

    test(
      'edge: undated materials go after every dated one in newestFirst, '
      'regardless of title',
      () {
        final result = sortMaterials(
          [undatedB, newer, older, undatedA],
          MaterialSortOrder.newestFirst,
        );
        expect(result.map((m) => m.materialId), [
          'newer',
          'older',
          'undatedA',
          'undatedB',
        ]);
      },
    );

    test(
      'edge: undated materials go before every dated one in oldestFirst, '
      'regardless of title',
      () {
        final result = sortMaterials(
          [newer, undatedB, older, undatedA],
          MaterialSortOrder.oldestFirst,
        );
        expect(result.map((m) => m.materialId), [
          'undatedA',
          'undatedB',
          'older',
          'newer',
        ]);
      },
    );

    test(
      'failure-adjacent: two undated materials break their tie by title, '
      'in both orders',
      () {
        final newestResult = sortMaterials(
          [undatedB, undatedA],
          MaterialSortOrder.newestFirst,
        );
        expect(newestResult.map((m) => m.materialId), [
          'undatedA',
          'undatedB',
        ]);

        final oldestResult = sortMaterials(
          [undatedB, undatedA],
          MaterialSortOrder.oldestFirst,
        );
        expect(oldestResult.map((m) => m.materialId), [
          'undatedA',
          'undatedB',
        ]);
      },
    );

    test('does not mutate the input list', () {
      final input = [newer, older];
      sortMaterials(input, MaterialSortOrder.oldestFirst);
      expect(input.map((m) => m.materialId), ['newer', 'older']);
    });
  });

  group('sortMaterials aToZ', () {
    test('normal: plain alphabetical, case-insensitive', () {
      final result = sortMaterials(
        [_material(id: '1', title: 'banana'), _material(id: '2', title: 'Apple')],
        MaterialSortOrder.aToZ,
      );
      expect(result.map((m) => m.materialId), ['2', '1']);
    });

    test('edge: natural order — "Lecture 2" sorts before "Lecture 10"', () {
      final result = sortMaterials(
        [
          _material(id: '10', title: 'Lecture 10'),
          _material(id: '2', title: 'Lecture 2'),
          _material(id: '1', title: 'Lecture 1'),
        ],
        MaterialSortOrder.aToZ,
      );
      expect(result.map((m) => m.materialId), ['1', '2', '10']);
    });

    test('edge: leading zeros are ignored for numeric comparison', () {
      final result = sortMaterials(
        [
          _material(id: 'a', title: 'Item 007'),
          _material(id: 'b', title: 'Item 07'),
          _material(id: 'c', title: 'Item 7'),
          _material(id: 'd', title: 'Item 10'),
        ],
        MaterialSortOrder.aToZ,
      );
      // 007 == 07 == 7 numerically; ties among them break by the (equal)
      // title text itself, so their relative order is stable/unchanged;
      // "10" sorts after all of them.
      expect(result.last.materialId, 'd');
      expect(result.map((m) => m.materialId).take(3), ['a', 'b', 'c']);
    });

    test(
      'failure-adjacent: a very long digit run (far past int range) '
      'compares correctly without overflowing or throwing — confirms the '
      'comparison never calls int.parse',
      () {
        final shorterRun = 'Item ${'9' * 40}'; // 40 nines
        final longerRun = 'Item 1${'0' * 40}'; // "1" followed by 40 zeros

        expect(
          () => sortMaterials(
            [
              _material(id: 'longer', title: longerRun),
              _material(id: 'shorter', title: shorterRun),
            ],
            MaterialSortOrder.aToZ,
          ),
          returnsNormally,
        );

        final result = sortMaterials(
          [
            _material(id: 'longer', title: longerRun),
            _material(id: 'shorter', title: shorterRun),
          ],
          MaterialSortOrder.aToZ,
        );
        // longerRun's digit run is 41 digits long vs shorterRun's 40 —
        // numerically larger purely by digit count once leading zeros are
        // stripped (neither has any here), which is exactly the
        // length-first comparison _compareDigitRuns uses instead of
        // int.parse.
        expect(result.map((m) => m.materialId), ['shorter', 'longer']);
      },
    );
  });

  group('highlightMatch', () {
    test('normal: a mid-title match splits into before/match/after', () {
      final result = highlightMatch('Lecture 1 — Introduction', 'lecture');
      expect(result, isNotNull);
      expect(result!.before, '');
      expect(result.match, 'Lecture');
      expect(result.after, ' 1 — Introduction');
    });

    test('normal: the matched span keeps the title\'s original casing', () {
      final result = highlightMatch('LECTURE NOTES', 'lecture');
      expect(result!.match, 'LECTURE');
    });

    test('edge: a blank query means no highlight', () {
      expect(highlightMatch('Lecture 1', '   '), isNull);
    });

    test('failure: no match in the title means no highlight', () {
      expect(highlightMatch('Lecture 1', 'midterm'), isNull);
    });

    test(
      'normal: non-ASCII titles still highlight correctly when lowercasing '
      'preserves length (the common, currently-only-reachable case)',
      () {
        final result = highlightMatch('İstanbul notes', 'notes');
        expect(result, isNotNull);
        expect(result!.match, 'notes');
        expect(result.before, 'İstanbul ');
        expect(result.after, '');
      },
    );

    test(
      'failure-adjacent (guard invariant, not a reachable case today): '
      "highlightMatch's length-mismatch guard exists for Unicode "
      'characters that expand under lowercasing — e.g. Turkish "İ" does, '
      'in full Unicode case folding (JavaScript/ICU). Dart\'s own '
      'String.toLowerCase only uses the always-length-preserving simple '
      'mappings, so no such input exists today — this locks that fact in '
      '(scanning every BMP + SMP codepoint) so the guard stays honestly '
      'documented as defensive-only unless/until a Dart change makes it '
      'reachable, at which point this test — not the feature — is what '
      'should fail first.',
      () {
        final lengthChanged = <int>[];
        for (var cp = 0; cp <= 0x2FFFF; cp++) {
          if (cp >= 0xD800 && cp <= 0xDFFF) continue; // surrogate halves
          final s = String.fromCharCode(cp);
          if (s.toLowerCase().length != s.length) lengthChanged.add(cp);
        }
        expect(
          lengthChanged,
          isEmpty,
          reason:
              'If this ever fails, String.toLowerCase can now change '
              "length for some codepoint — highlightMatch's guard is no "
              'longer purely defensive, and deserves a real test built on '
              'one of these codepoints instead of this invariant check.',
        );
      },
    );
  });
}
