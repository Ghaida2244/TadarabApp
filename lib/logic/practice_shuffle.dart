import 'dart:math';

import '../models/flashcard.dart';
import '../models/question.dart';

/// Pure, Random-injectable shuffle logic for Quiz's "Practice Now" and
/// Flashcards' "Review Now" — kept in one shared file (rather than
/// Quiz-only or Flashcards-only) since both features need the same shape
/// of "shuffle a list, deterministically in a test" logic. Neither mode
/// writes anything to Firestore; this file has no Firestore dependency at
/// all, by design, so it can't accidentally grow one.

/// Shuffles [options] into a new order, guaranteeing the position of
/// [correctAnswer] differs from wherever it was in [options] — whenever
/// there are at least 2 options. [correctAnswer] is matched by text (it's
/// stored as a literal string, not an index, per [Question.correctAnswer]),
/// not by index, so reordering is always safe.
///
/// Never loops: exactly one real shuffle, then — only if the correct
/// answer happened to land back on its original index — one deterministic
/// swap moves it off that index. There is no retry loop, so this
/// terminates even for a 2-option question, where a shuffle has a real
/// chance of leaving everything exactly where it started.
List<String> shuffleOptionsAwayFromOriginalPosition({
  required List<String> options,
  required String correctAnswer,
  Random? random,
}) {
  if (options.length < 2) return List<String>.from(options);
  final originalIndex = options.indexOf(correctAnswer);
  final shuffled = List<String>.from(options)..shuffle(random ?? Random());
  if (originalIndex == -1) return shuffled;
  final newIndex = shuffled.indexOf(correctAnswer);
  if (newIndex != originalIndex) return shuffled;
  // Landed back where it started — swap it into a different slot. Slot 0
  // unless the correct answer is already there, in which case slot 1
  // (always exists: options.length >= 2 here).
  final swapWith = newIndex == 0 ? 1 : 0;
  final temp = shuffled[swapWith];
  shuffled[swapWith] = shuffled[newIndex];
  shuffled[newIndex] = temp;
  return shuffled;
}

/// Shuffles [questions] into a new order and reshuffles each one's own
/// [Question.options] (see [shuffleOptionsAwayFromOriginalPosition]) — the
/// full transform Quiz's Practice Now applies to a fresh practice round.
/// Every other field (including [Question.correctAnswer] and
/// [Question.studentAnswer]) is carried through unchanged; only order and
/// `options` change.
List<Question> shuffleQuestionsForPractice(
  List<Question> questions, {
  Random? random,
}) {
  final effectiveRandom = random ?? Random();
  final shuffled = List<Question>.from(questions)..shuffle(effectiveRandom);
  return [
    for (final q in shuffled)
      q.copyWith(
        options: shuffleOptionsAwayFromOriginalPosition(
          options: q.options,
          correctAnswer: q.correctAnswer,
          random: effectiveRandom,
        ),
      ),
  ];
}

/// Shuffles [flashcards] into a new order for Flashcards' Review Now pass
/// — a plain order shuffle, no "away from original position" guarantee
/// needed (a flashcard has no analogous notion of a correct option/index).
List<Flashcard> shuffleFlashcardsForReview(
  List<Flashcard> flashcards, {
  Random? random,
}) {
  return List<Flashcard>.from(flashcards)..shuffle(random ?? Random());
}
