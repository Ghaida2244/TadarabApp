import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/models/question.dart';

void main() {
  Question aQuestion({String? studentAnswer, bool isReported = false}) {
    return Question(
      questionId: 'q1',
      questionText: 'What is a database?',
      correctAnswer: 'A collection of related data',
      explanation: 'Because...',
      sourceLocation: 'Lecture 1 - Slide 8',
      studentAnswer: studentAnswer,
      options: const [
        'A collection of unrelated data',
        'A collection of related data',
        'A programming language',
        'A hardware device',
      ],
      sessionId: 'session-1',
      isReported: isReported,
    );
  }

  group('isCorrect', () {
    test('normal case: matches the correct answer', () {
      final q = aQuestion(studentAnswer: 'A collection of related data');
      expect(q.isCorrect, isTrue);
    });

    test('edge case: a wrong pick is false, not null', () {
      final q = aQuestion(studentAnswer: 'A programming language');
      expect(q.isCorrect, isFalse);
    });

    test('failure/unanswered case: null studentAnswer yields null, not false', () {
      final q = aQuestion();
      expect(q.isCorrect, isNull);
    });
  });

  group('copyWith', () {
    test('normal case: sets studentAnswer without touching other fields', () {
      final q = aQuestion();
      final answered = q.copyWith(studentAnswer: 'A collection of related data');

      expect(answered.studentAnswer, 'A collection of related data');
      expect(answered.questionId, q.questionId);
      expect(answered.isReported, q.isReported);
    });

    test('edge case: omitting an argument preserves the existing value', () {
      final q = aQuestion(studentAnswer: 'A programming language');
      final flagged = q.copyWith(isReported: true);

      expect(flagged.studentAnswer, 'A programming language');
      expect(flagged.isReported, isTrue);
    });
  });

  group('toFirestore', () {
    test('defaults isReported to false when constructed without it', () {
      final q = aQuestion();
      expect(q.toFirestore()['isReported'], false);
    });

    test('carries an explicit report flag through', () {
      final q = aQuestion(isReported: true);
      expect(q.toFirestore()['isReported'], true);
    });
  });
}
