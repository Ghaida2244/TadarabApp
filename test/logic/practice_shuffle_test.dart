import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/logic/practice_shuffle.dart';
import 'package:tadarab_app/models/flashcard.dart';
import 'package:tadarab_app/models/question.dart';

Question _question({
  required String id,
  List<String> options = const ['A', 'B', 'C', 'D'],
  String correctAnswer = 'B',
}) {
  return Question(
    questionId: id,
    questionText: 'Question $id',
    correctAnswer: correctAnswer,
    explanation: 'Because.',
    sourceLocation: 'Slide 1',
    options: options,
    sessionId: 'session-1',
  );
}

Flashcard _card(String id) => Flashcard(
  flashcardId: id,
  frontText: 'front-$id',
  backText: 'back-$id',
  reviewStatus: null,
  sourceLocation: 'Slide 1',
  sessionId: 'session-1',
  cardIndex: 0,
);

void main() {
  group('shuffleOptionsAwayFromOriginalPosition', () {
    test(
      'normal case: the result contains exactly the same options, just '
      'reordered',
      () {
        const options = ['A', 'B', 'C', 'D'];
        final shuffled = shuffleOptionsAwayFromOriginalPosition(
          options: options,
          correctAnswer: 'B',
          random: Random(1),
        );
        expect(shuffled.toSet(), options.toSet());
        expect(shuffled.length, options.length);
      },
    );

    test(
      'normal case: across many seeds, the order is capable of differing '
      'from the original',
      () {
        const options = ['A', 'B', 'C', 'D'];
        var sawDifferentOrder = false;
        for (var seed = 0; seed < 50; seed++) {
          final shuffled = shuffleOptionsAwayFromOriginalPosition(
            options: options,
            correctAnswer: 'B',
            random: Random(seed),
          );
          if (!identical(shuffled, options) &&
              !_sameOrder(shuffled, options)) {
            sawDifferentOrder = true;
            break;
          }
        }
        expect(sawDifferentOrder, isTrue);
      },
    );

    test(
      'normal case: the correct answer\'s position always differs from '
      'its original position, across many seeds',
      () {
        const options = ['A', 'B', 'C', 'D'];
        final originalIndex = options.indexOf('B');
        for (var seed = 0; seed < 100; seed++) {
          final shuffled = shuffleOptionsAwayFromOriginalPosition(
            options: options,
            correctAnswer: 'B',
            random: Random(seed),
          );
          expect(
            shuffled.indexOf('B'),
            isNot(originalIndex),
            reason: 'seed $seed produced the same position as the original',
          );
        }
      },
    );

    test(
      'edge case: exactly 2 options still guarantees a different position, '
      'across many seeds (the case most likely to shuffle back to itself)',
      () {
        const options = ['Yes', 'No'];
        final originalIndex = options.indexOf('Yes');
        for (var seed = 0; seed < 100; seed++) {
          final shuffled = shuffleOptionsAwayFromOriginalPosition(
            options: options,
            correctAnswer: 'Yes',
            random: Random(seed),
          );
          expect(shuffled.toSet(), options.toSet());
          expect(shuffled.indexOf('Yes'), isNot(originalIndex));
        }
      },
    );

    test(
      'failure case: a single-option question returns immediately, '
      'unchanged — no hang, no crash',
      () {
        final shuffled = shuffleOptionsAwayFromOriginalPosition(
          options: const ['Only'],
          correctAnswer: 'Only',
          random: Random(1),
        );
        expect(shuffled, ['Only']);
      },
    );

    test('edge case: an empty options list returns empty, not a crash', () {
      final shuffled = shuffleOptionsAwayFromOriginalPosition(
        options: const [],
        correctAnswer: 'X',
        random: Random(1),
      );
      expect(shuffled, isEmpty);
    });

    test(
      'failure-adjacent: a correctAnswer not actually present in options '
      'still returns a valid shuffle, not a crash',
      () {
        final shuffled = shuffleOptionsAwayFromOriginalPosition(
          options: const ['A', 'B', 'C'],
          correctAnswer: 'Not In List',
          random: Random(1),
        );
        expect(shuffled.toSet(), {'A', 'B', 'C'});
      },
    );
  });

  group('shuffleQuestionsForPractice', () {
    test('normal case: contains the exact same questions, just reordered', () {
      final questions = [
        _question(id: 'q1'),
        _question(id: 'q2'),
        _question(id: 'q3'),
      ];
      final shuffled = shuffleQuestionsForPractice(questions, random: Random(1));

      expect(
        shuffled.map((q) => q.questionId).toSet(),
        {'q1', 'q2', 'q3'},
      );
      expect(shuffled.length, questions.length);
    });

    test(
      'normal case: across many seeds, question order is capable of '
      'differing from the input order',
      () {
        final questions = [
          _question(id: 'q1'),
          _question(id: 'q2'),
          _question(id: 'q3'),
          _question(id: 'q4'),
        ];
        var sawDifferentOrder = false;
        for (var seed = 0; seed < 50; seed++) {
          final shuffled = shuffleQuestionsForPractice(questions, random: Random(seed));
          if (shuffled.map((q) => q.questionId).toList().join() !=
              questions.map((q) => q.questionId).join()) {
            sawDifferentOrder = true;
            break;
          }
        }
        expect(sawDifferentOrder, isTrue);
      },
    );

    test(
      'normal case: every question\'s correct answer position differs '
      'from its original, and correctAnswer/text/sessionId are untouched',
      () {
        final questions = [
          _question(id: 'q1', correctAnswer: 'B'),
          _question(id: 'q2', correctAnswer: 'C', options: const ['X', 'Y', 'C']),
        ];
        final shuffled = shuffleQuestionsForPractice(questions, random: Random(2));

        for (final original in questions) {
          final after = shuffled.firstWhere((q) => q.questionId == original.questionId);
          expect(after.correctAnswer, original.correctAnswer);
          expect(after.questionText, original.questionText);
          expect(after.sessionId, original.sessionId);
          expect(after.options.toSet(), original.options.toSet());
          expect(
            after.options.indexOf(after.correctAnswer),
            isNot(original.options.indexOf(original.correctAnswer)),
          );
        }
      },
    );

    test('edge case: an empty list returns empty, not a crash', () {
      expect(shuffleQuestionsForPractice(const [], random: Random(1)), isEmpty);
    });

    test(
      'failure case: a single question with a single option does not hang',
      () {
        final questions = [
          _question(id: 'q1', options: const ['Only'], correctAnswer: 'Only'),
        ];
        final shuffled = shuffleQuestionsForPractice(questions, random: Random(1));
        expect(shuffled.single.options, ['Only']);
      },
    );
  });

  group('shuffleFlashcardsForReview', () {
    test('normal case: contains the exact same flashcards, just reordered', () {
      final cards = [_card('a'), _card('b'), _card('c')];
      final shuffled = shuffleFlashcardsForReview(cards, random: Random(1));

      expect(shuffled.map((c) => c.flashcardId).toSet(), {'a', 'b', 'c'});
      expect(shuffled.length, cards.length);
    });

    test(
      'normal case: across many seeds, order is capable of differing from '
      'the input order',
      () {
        final cards = [_card('a'), _card('b'), _card('c'), _card('d')];
        var sawDifferentOrder = false;
        for (var seed = 0; seed < 50; seed++) {
          final shuffled = shuffleFlashcardsForReview(cards, random: Random(seed));
          if (shuffled.map((c) => c.flashcardId).join() !=
              cards.map((c) => c.flashcardId).join()) {
            sawDifferentOrder = true;
            break;
          }
        }
        expect(sawDifferentOrder, isTrue);
      },
    );

    test('edge case: an empty list returns empty, not a crash', () {
      expect(shuffleFlashcardsForReview(const [], random: Random(1)), isEmpty);
    });

    test('edge case: a single-card list returns that one card, unchanged', () {
      final cards = [_card('solo')];
      expect(
        shuffleFlashcardsForReview(cards, random: Random(1)).single.flashcardId,
        'solo',
      );
    });

    test('failure-adjacent: does not mutate the input list', () {
      final cards = [_card('a'), _card('b'), _card('c')];
      shuffleFlashcardsForReview(cards, random: Random(1));
      expect(cards.map((c) => c.flashcardId).toList(), ['a', 'b', 'c']);
    });
  });
}

bool _sameOrder(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
