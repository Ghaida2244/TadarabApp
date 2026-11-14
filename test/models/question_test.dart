import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/models/question.dart';

void main() {
  Question aQuestion({String? studentAnswer}) {
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
    );
  }

  late FakeFirebaseFirestore firestore;

  setUp(() {
    firestore = FakeFirebaseFirestore();
  });

  Future<Question> seedAndRead(Map<String, dynamic> data) async {
    final ref = await firestore.collection('questions').add(data);
    final doc = await ref.get();
    return Question.fromFirestore(doc);
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
    });

    test('failure case: copyWith cannot clear studentAnswer back to null', () {
      // Documents the exact gap asUnanswered() exists to fix: `?? this.
      // studentAnswer` can't distinguish "clear it" from "leave it alone".
      final q = aQuestion(studentAnswer: 'A programming language');
      final stillAnswered = q.copyWith(studentAnswer: null);
      expect(stillAnswered.studentAnswer, 'A programming language');
    });

    test(
      'normal case: options replaces the whole option list, e.g. a '
      'practice-round reshuffle',
      () {
        final q = aQuestion();
        final reordered = q.copyWith(
          options: const ['A programming language', 'A collection of related data'],
        );

        expect(reordered.options, [
          'A programming language',
          'A collection of related data',
        ]);
        expect(reordered.correctAnswer, q.correctAnswer);
        expect(reordered.questionId, q.questionId);
      },
    );

    test('edge case: omitting options preserves the existing order', () {
      final q = aQuestion();
      final sameOptions = q.copyWith(studentAnswer: 'A programming language');
      expect(sameOptions.options, q.options);
    });
  });

  group('asUnanswered', () {
    test('normal case: clears a previously-recorded answer', () {
      final q = aQuestion(studentAnswer: 'A programming language');
      final fresh = q.asUnanswered();

      expect(fresh.studentAnswer, isNull);
      expect(fresh.isCorrect, isNull);
    });

    test('edge case: an already-unanswered question stays unanswered', () {
      final q = aQuestion();
      expect(q.asUnanswered().studentAnswer, isNull);
    });

    test('does not touch any other field', () {
      final q = aQuestion(studentAnswer: 'A programming language');
      final fresh = q.asUnanswered();

      expect(fresh.questionId, q.questionId);
      expect(fresh.questionText, q.questionText);
      expect(fresh.correctAnswer, q.correctAnswer);
      expect(fresh.explanation, q.explanation);
      expect(fresh.sourceLocation, q.sourceLocation);
      expect(fresh.options, q.options);
      expect(fresh.sessionId, q.sessionId);
    });
  });

  group('fromFirestore', () {
    test('normal case: reads every field from a real document', () async {
      final q = await seedAndRead({
        'questionText': 'What is a database?',
        'correctAnswer': 'A collection of related data',
        'explanation': 'Because...',
        'sourceLocation': 'Lecture 1 - Slide 8',
        'studentAnswer': 'A collection of related data',
        'options': [
          'A collection of unrelated data',
          'A collection of related data',
          'A programming language',
          'A hardware device',
        ],
        'sessionId': 'session-1',
      });

      expect(q.questionText, 'What is a database?');
      expect(q.correctAnswer, 'A collection of related data');
      expect(q.explanation, 'Because...');
      expect(q.sourceLocation, 'Lecture 1 - Slide 8');
      expect(q.studentAnswer, 'A collection of related data');
      expect(q.options, [
        'A collection of unrelated data',
        'A collection of related data',
        'A programming language',
        'A hardware device',
      ]);
      expect(q.sessionId, 'session-1');
    });

    test(
      'edge case: a stray isReported field from an older document is '
      'silently ignored, with no error, and every other field still reads '
      'correctly',
      () async {
        final q = await seedAndRead({
          'questionText': 'What is a database?',
          'correctAnswer': 'A collection of related data',
          'explanation': 'Because...',
          'sourceLocation': 'Lecture 1 - Slide 8',
          'studentAnswer': 'A collection of related data',
          'options': [
            'A collection of unrelated data',
            'A collection of related data',
            'A programming language',
            'A hardware device',
          ],
          'sessionId': 'session-1',
          // Leftover from the since-removed "Report this question" feature —
          // must not throw and must not surface anywhere on Question.
          'isReported': true,
        });

        expect(q.questionText, 'What is a database?');
        expect(q.correctAnswer, 'A collection of related data');
        expect(q.explanation, 'Because...');
        expect(q.sourceLocation, 'Lecture 1 - Slide 8');
        expect(q.studentAnswer, 'A collection of related data');
        expect(q.options, [
          'A collection of unrelated data',
          'A collection of related data',
          'A programming language',
          'A hardware device',
        ]);
        expect(q.sessionId, 'session-1');
      },
    );
  });

  group('toFirestore', () {
    test('normal case: writes exactly the expected fields, no isReported', () {
      final q = aQuestion(studentAnswer: 'A collection of related data');
      final data = q.toFirestore();

      expect(data.keys.toSet(), {
        'questionText',
        'correctAnswer',
        'explanation',
        'sourceLocation',
        'studentAnswer',
        'options',
        'sessionId',
      });
      expect(data.containsKey('isReported'), isFalse);
      expect(data['questionText'], q.questionText);
      expect(data['correctAnswer'], q.correctAnswer);
      expect(data['explanation'], q.explanation);
      expect(data['sourceLocation'], q.sourceLocation);
      expect(data['studentAnswer'], q.studentAnswer);
      expect(data['options'], q.options);
      expect(data['sessionId'], q.sessionId);
    });

    test(
      'normal case: fromFirestore(toFirestore(q)) round-trips every field '
      'except questionId (Firestore assigns that on write, not this method)',
      () async {
        final q = aQuestion(studentAnswer: 'A collection of related data');
        final roundTripped = await seedAndRead(q.toFirestore());

        expect(roundTripped.questionText, q.questionText);
        expect(roundTripped.correctAnswer, q.correctAnswer);
        expect(roundTripped.explanation, q.explanation);
        expect(roundTripped.sourceLocation, q.sourceLocation);
        expect(roundTripped.studentAnswer, q.studentAnswer);
        expect(roundTripped.options, q.options);
        expect(roundTripped.sessionId, q.sessionId);
      },
    );
  });
}
