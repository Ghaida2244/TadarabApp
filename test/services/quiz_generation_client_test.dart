import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tadarab_app/models/enums.dart';
import 'package:tadarab_app/services/quiz_generation_client.dart';

void main() {
  final endpoint = Uri.parse('https://example.test/generate');
  final materials = [
    GenerationMaterial(title: 'Lecture 1', sourceText: '[Slide 1]\nPhotosynthesis...'),
  ];

  QuizGenerationClient client(
    http.Client httpClient, {
    Future<String?> Function()? idTokenProvider,
  }) {
    return QuizGenerationClient(
      httpClient: httpClient,
      endpoint: endpoint,
      idTokenProvider: idTokenProvider ?? () async => 'fake-token',
    );
  }

  test('normal case: a 200 response parses items and note', () async {
    final mock = MockClient((request) async {
      expect(request.url, endpoint);
      expect(request.headers['Authorization'], 'Bearer fake-token');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['type'], 'quiz');
      expect(body['count'], 5);
      expect(body['difficulty'], ['easy', 'hard']);
      expect(body['materials'], [
        {'title': 'Lecture 1', 'sourceText': '[Slide 1]\nPhotosynthesis...'},
      ]);

      return http.Response(
        jsonEncode({
          'uid': 'u1',
          'type': 'quiz',
          'items': [
            {
              'questionText': 'What is a database?',
              'options': ['A', 'B', 'C', 'D'],
              'correctAnswer': 'B',
              'explanation': 'Because...',
              'sourceLocation': 'Slide 1',
              'difficulty': 'easy',
            },
          ],
          'note': null,
        }),
        200,
      );
    });

    final result = await client(mock).generateQuiz(
      count: 5,
      difficulties: [DifficultyLevel.easy, DifficultyLevel.hard],
      materials: materials,
    );

    expect(result.items, hasLength(1));
    expect(result.items.single.questionText, 'What is a database?');
    expect(result.items.single.difficulty, DifficultyLevel.easy);
    expect(result.note, isNull);
  });

  test('normal case: an omitted customPrompt is not sent at all', () async {
    final mock = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body.containsKey('customPrompt'), isFalse);
      return http.Response(jsonEncode({'items': [], 'note': null}), 200);
    });

    await client(mock).generateQuiz(
      count: 5,
      difficulties: [DifficultyLevel.medium],
      materials: materials,
    );
  });

  test('edge case: fewer items than requested still parses, with a note', () async {
    final mock = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'items': [],
          'note': 'Only 0 of the 10 requested items could be generated.',
        }),
        200,
      );
    });

    final result = await client(mock).generateQuiz(
      count: 10,
      difficulties: [DifficultyLevel.hard],
      materials: materials,
    );

    expect(result.items, isEmpty);
    expect(result.note, contains('Only 0 of the 10'));
  });

  test('failure case: not signed in throws before any HTTP call', () async {
    var called = false;
    final mock = MockClient((request) async {
      called = true;
      return http.Response('{}', 200);
    });

    expect(
      () => client(
        mock,
        idTokenProvider: () async => null,
      ).generateQuiz(count: 5, difficulties: [DifficultyLevel.easy], materials: materials),
      throwsA(isA<GenerationFailure>()),
    );
    expect(called, isFalse);
  });

  test('failure case: a non-200 response surfaces the server message', () async {
    final mock = MockClient((request) async {
      return http.Response(
        jsonEncode({'error': 'Bad Request', 'message': '"count" must be a positive integer'}),
        400,
      );
    });

    await expectLater(
      client(mock).generateQuiz(count: 5, difficulties: [DifficultyLevel.easy], materials: materials),
      throwsA(
        isA<GenerationFailure>().having(
          (e) => e.message,
          'message',
          '"count" must be a positive integer',
        ),
      ),
    );
  });

  test('failure case: a network exception becomes a GenerationFailure', () async {
    final mock = MockClient((request) async {
      throw const SocketExceptionStub();
    });

    await expectLater(
      client(mock).generateQuiz(count: 5, difficulties: [DifficultyLevel.easy], materials: materials),
      throwsA(isA<GenerationFailure>()),
    );
  });

  test('failure case: a malformed body (no items list) is a GenerationFailure', () async {
    final mock = MockClient((request) async {
      return http.Response(jsonEncode({'unexpected': true}), 200);
    });

    await expectLater(
      client(mock).generateQuiz(count: 5, difficulties: [DifficultyLevel.easy], materials: materials),
      throwsA(isA<GenerationFailure>()),
    );
  });
}

/// A minimal stand-in for a thrown network error — the real exception type
/// doesn't matter to [QuizGenerationClient], which catches broadly and
/// reports a generic connection failure to the student.
class SocketExceptionStub implements Exception {
  const SocketExceptionStub();
}
