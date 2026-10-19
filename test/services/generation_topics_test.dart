import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/services/generation_topics.dart';

void main() {
  group('parseCoveredTopics', () {
    test('normal: reads a plain list of strings', () {
      expect(parseCoveredTopics(['Normalization', 'ACID']), [
        'Normalization',
        'ACID',
      ]);
    });

    test('edge: an empty list stays empty', () {
      expect(parseCoveredTopics(<dynamic>[]), isEmpty);
    });

    test('failure: null defaults to empty, not a crash', () {
      expect(parseCoveredTopics(null), isEmpty);
    });

    test('failure: a non-list value defaults to empty, not a crash', () {
      expect(parseCoveredTopics('not a list'), isEmpty);
    });

    test('failure: non-string entries are dropped, not thrown on', () {
      expect(parseCoveredTopics(['Normalization', 42, null, true]), [
        'Normalization',
      ]);
    });
  });

  group('buildPreviousTopics', () {
    test('normal: passes through a short, clean list unchanged', () {
      expect(buildPreviousTopics(['Normalization', 'ACID']), [
        'Normalization',
        'ACID',
      ]);
    });

    test('edge: an empty source list yields an empty result', () {
      expect(buildPreviousTopics(const []), isEmpty);
    });

    test('normal: drops blank/whitespace-only entries', () {
      expect(buildPreviousTopics(['Normalization', '', '   ']), [
        'Normalization',
      ]);
    });

    test(
      'normal: drops case-insensitive duplicates, keeping the first '
      'occurrence\'s casing',
      () {
        expect(
          buildPreviousTopics(['Normalization', 'normalization', 'ACID']),
          ['Normalization', 'ACID'],
        );
      },
    );

    test('normal: trims each entry before comparing/storing', () {
      expect(buildPreviousTopics(['  Normalization  ']), ['Normalization']);
    });

    test(
      'failure-adjacent: an entry longer than the Worker\'s per-entry limit '
      'is truncated to exactly that limit',
      () {
        final long = 'A' * (kMaxPreviousTopicLength + 20);
        final result = buildPreviousTopics([long]);
        expect(result.single.length, kMaxPreviousTopicLength);
        expect(result.single, 'A' * kMaxPreviousTopicLength);
      },
    );

    test(
      'failure-adjacent: more entries than the Worker\'s list-length limit '
      'are capped, keeping only the first ones',
      () {
        final many = List.generate(kMaxPreviousTopics + 10, (i) => 'topic-$i');
        final result = buildPreviousTopics(many);
        expect(result.length, kMaxPreviousTopics);
        expect(result.first, 'topic-0');
      },
    );
  });
}
