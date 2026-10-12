import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tadarab_app/models/enums.dart';
import 'package:tadarab_app/models/flashcard.dart';
import 'package:tadarab_app/models/flashcard_session.dart';
import 'package:tadarab_app/models/study_material.dart';
import 'package:tadarab_app/services/flashcard_service.dart';

/// A [FlashcardService] with its Firestore-*read* methods swapped for
/// canned data, so [generateFlashcards]/[retake]'s real Worker-calling and
/// request-body logic can be exercised with a mocked [http.Client] — no
/// real Firestore needed for anything these tests check. `retake()` now
/// reads the source session first (for its `coveredTopics`, to build
/// `previousTopics`) before calling the Worker — [fetchSession] is faked
/// here for exactly that read. Its Firestore *write* path
/// (`_firestore.batch()...commit()`, and the private `_fetchSessionsInGroup`
/// read just before it, both reached only once the Worker returns a
/// non-empty result) is never exercised here — there's no fake Firestore
/// available in this project (confirmed: no such package is even a
/// dependency), and `_fetchSessionsInGroup` is library-private so a test
/// file can't override it the way it can [fetchSession] — so every test
/// below deliberately stays on the side of that line where the real
/// behavior is still being exercised for real: an empty or failing Worker
/// response, which `retake()` must reject before ever writing to Firestore.
class _TestFlashcardService extends FlashcardService {
  _TestFlashcardService({
    required http.Client httpClient,
    this.materials = const [],
    this.session,
  }) : super(
         uid: 'uid-1',
         courseId: 'course-1',
         httpClient: httpClient,
         idTokenProvider: () async => 'fake-token',
         endpoint: Uri.parse('https://example.test/generate'),
       );

  final List<StudyMaterial> materials;

  /// Returned by [fetchSession]; defaults to a plain session with no
  /// stored `coveredTopics` (an "old session" — see
  /// [FlashcardService.retake]'s `previousTopics` handling).
  final FlashcardSession? session;

  /// Set true the moment `fetchFlashcards` runs — only reachable from the
  /// real `retake()` after a successful, non-empty Worker response (see the
  /// class doc comment above) — so "false" after a failed `retake()` call
  /// is this file's proof that nothing past that point ran.
  bool fetchFlashcardsCalled = false;

  @override
  Future<List<StudyMaterial>> fetchMaterials() async => materials;

  @override
  Future<FlashcardSession> fetchSession(String sessionId) async {
    return session ??
        FlashcardSession(
          sessionId: sessionId,
          createdAt: DateTime(2026, 1, 1),
          difficultyLevels: const [DifficultyLevel.medium],
          email: 'student@example.com',
          courseId: 'course-1',
          materialIds: const ['m1'],
          materialTitles: const ['Lecture 1'],
        );
  }

  @override
  Future<List<Flashcard>> fetchFlashcards(String sessionId) async {
    fetchFlashcardsCalled = true;
    return const [];
  }
}

final _material = StudyMaterial(
  materialId: 'm1',
  title: 'Lecture 1',
  type: 'pptx',
  document: 'materials/m1.pptx',
  courseId: 'course-1',
  extractedText: '[Slide 1: Intro]\nSample text.',
);

http.Response _emptyItemsResponse({String? note, dynamic coveredTopics}) =>
    http.Response(
      jsonEncode({
        'items': <dynamic>[],
        'note': note,
        if (coveredTopics != null) 'coveredTopics': coveredTopics,
      }),
      200,
    );

void main() {
  group('generateFlashcards: isRetake', () {
    test('normal: sends isRetake: true in the request body when passed', () async {
      Map<String, dynamic>? capturedBody;
      final mock = MockClient((request) async {
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return _emptyItemsResponse();
      });
      final service = _TestFlashcardService(
        httpClient: mock,
        materials: [_material],
      );

      await service.generateFlashcards(
        materialIds: ['m1'],
        difficulties: [DifficultyLevel.medium],
        count: 5,
        isRetake: true,
      );

      expect(capturedBody?['isRetake'], true);
    });

    test('normal: defaults to isRetake: false when not passed', () async {
      Map<String, dynamic>? capturedBody;
      final mock = MockClient((request) async {
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return _emptyItemsResponse();
      });
      final service = _TestFlashcardService(
        httpClient: mock,
        materials: [_material],
      );

      await service.generateFlashcards(
        materialIds: ['m1'],
        difficulties: [DifficultyLevel.medium],
        count: 5,
      );

      expect(capturedBody?['isRetake'], false);
    });

    test(
      'normal: sends previousTopics in the request body when isRetake and '
      'non-empty',
      () async {
        Map<String, dynamic>? capturedBody;
        final mock = MockClient((request) async {
          capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
          return _emptyItemsResponse();
        });
        final service = _TestFlashcardService(
          httpClient: mock,
          materials: [_material],
        );

        await service.generateFlashcards(
          materialIds: ['m1'],
          difficulties: [DifficultyLevel.medium],
          count: 5,
          isRetake: true,
          previousTopics: ['Normalization', 'ACID'],
        );

        expect(capturedBody?['previousTopics'], ['Normalization', 'ACID']);
      },
    );

    test(
      'edge: previousTopics is omitted when empty, even if isRetake is true',
      () async {
        Map<String, dynamic>? capturedBody;
        final mock = MockClient((request) async {
          capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
          return _emptyItemsResponse();
        });
        final service = _TestFlashcardService(
          httpClient: mock,
          materials: [_material],
        );

        await service.generateFlashcards(
          materialIds: ['m1'],
          difficulties: [DifficultyLevel.medium],
          count: 5,
          isRetake: true,
        );

        expect(capturedBody?.containsKey('previousTopics'), isFalse);
      },
    );

    test(
      'edge: previousTopics is omitted when isRetake is false, even if '
      'given',
      () async {
        Map<String, dynamic>? capturedBody;
        final mock = MockClient((request) async {
          capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
          return _emptyItemsResponse();
        });
        final service = _TestFlashcardService(
          httpClient: mock,
          materials: [_material],
        );

        await service.generateFlashcards(
          materialIds: ['m1'],
          difficulties: [DifficultyLevel.medium],
          count: 5,
          previousTopics: ['Normalization'],
        );

        expect(capturedBody?.containsKey('previousTopics'), isFalse);
      },
    );
  });

  group('generateFlashcards: coveredTopics parsing', () {
    test('normal: reads coveredTopics from the response', () async {
      final mock = MockClient(
        (request) async => _emptyItemsResponse(
          coveredTopics: ['Normalization', 'ACID'],
        ),
      );
      final service = _TestFlashcardService(
        httpClient: mock,
        materials: [_material],
      );

      final result = await service.generateFlashcards(
        materialIds: ['m1'],
        difficulties: [DifficultyLevel.medium],
        count: 5,
      );

      expect(result.coveredTopics, ['Normalization', 'ACID']);
    });

    test('failure: a missing coveredTopics field defaults to empty, not a '
        'crash', () async {
      final mock = MockClient((request) async => _emptyItemsResponse());
      final service = _TestFlashcardService(
        httpClient: mock,
        materials: [_material],
      );

      final result = await service.generateFlashcards(
        materialIds: ['m1'],
        difficulties: [DifficultyLevel.medium],
        count: 5,
      );

      expect(result.coveredTopics, isEmpty);
    });

    test('failure: a non-list coveredTopics field defaults to empty, not a '
        'crash', () async {
      final mock = MockClient(
        (request) async => _emptyItemsResponse(coveredTopics: 'not a list'),
      );
      final service = _TestFlashcardService(
        httpClient: mock,
        materials: [_material],
      );

      final result = await service.generateFlashcards(
        materialIds: ['m1'],
        difficulties: [DifficultyLevel.medium],
        count: 5,
      );

      expect(result.coveredTopics, isEmpty);
    });
  });

  group('retake', () {
    test(
      'normal: calls the Worker with isRetake: true and the exact settings '
      'it was given',
      () async {
        Map<String, dynamic>? capturedBody;
        final mock = MockClient((request) async {
          capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
          // Zero items is the one response shape that lets retake() make
          // the real HTTP call (so the request is really captured) while
          // guaranteeing it never reaches its Firestore write path — see
          // the class doc comment above.
          return _emptyItemsResponse();
        });
        final service = _TestFlashcardService(
          httpClient: mock,
          materials: [_material],
        );

        await expectLater(
          service.retake(
            sessionId: 'session-1',
            materialIds: ['m1'],
            difficulties: [DifficultyLevel.hard],
            count: 12,
            customPrompt: 'Focus on chapter 2.',
          ),
          throwsA(isA<FlashcardFailure>()),
        );

        expect(capturedBody?['isRetake'], true);
        expect(capturedBody?['count'], 12);
        expect(capturedBody?['difficulty'], ['hard']);
        expect(capturedBody?['customPrompt'], 'Focus on chapter 2.');
        expect(capturedBody?['materials'], [
          {
            'title': 'Lecture 1',
            'sourceText': '[Slide 1: Intro]\nSample text.',
          },
        ]);
      },
    );

    test(
      'normal: builds previousTopics from the SOURCE session\'s own stored '
      'coveredTopics',
      () async {
        Map<String, dynamic>? capturedBody;
        final mock = MockClient((request) async {
          capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
          return _emptyItemsResponse();
        });
        final service = _TestFlashcardService(
          httpClient: mock,
          materials: [_material],
          session: FlashcardSession(
            sessionId: 'session-1',
            createdAt: DateTime(2026, 1, 1),
            difficultyLevels: const [DifficultyLevel.medium],
            email: 'student@example.com',
            courseId: 'course-1',
            materialIds: const ['m1'],
            materialTitles: const ['Lecture 1'],
            coveredTopics: const ['Normalization', 'ACID'],
          ),
        );

        await expectLater(
          service.retake(
            sessionId: 'session-1',
            materialIds: ['m1'],
            difficulties: [DifficultyLevel.medium],
            count: 5,
          ),
          throwsA(isA<FlashcardFailure>()),
        );

        expect(capturedBody?['previousTopics'], ['Normalization', 'ACID']);
      },
    );

    test(
      'edge: an old source session with no stored coveredTopics sends no '
      'previousTopics at all',
      () async {
        Map<String, dynamic>? capturedBody;
        final mock = MockClient((request) async {
          capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
          return _emptyItemsResponse();
        });
        final service = _TestFlashcardService(
          httpClient: mock,
          materials: [_material],
          session: FlashcardSession(
            sessionId: 'session-1',
            createdAt: DateTime(2026, 1, 1),
            difficultyLevels: const [DifficultyLevel.medium],
            email: 'student@example.com',
            courseId: 'course-1',
            materialIds: const ['m1'],
            materialTitles: const ['Lecture 1'],
            // coveredTopics defaults to empty — an "old" session.
          ),
        );

        await expectLater(
          service.retake(
            sessionId: 'session-1',
            materialIds: ['m1'],
            difficulties: [DifficultyLevel.medium],
            count: 5,
          ),
          throwsA(isA<FlashcardFailure>()),
        );

        expect(capturedBody?.containsKey('previousTopics'), isFalse);
      },
    );

    test(
      'failure: a zero-item Worker response is rejected before Firestore '
      'is ever written to',
      () async {
        final mock = MockClient(
          (request) async => _emptyItemsResponse(note: 'No suitable content.'),
        );
        final service = _TestFlashcardService(
          httpClient: mock,
          materials: [_material],
        );

        await expectLater(
          service.retake(
            sessionId: 'session-1',
            materialIds: ['m1'],
            difficulties: [DifficultyLevel.medium],
            count: 5,
          ),
          throwsA(
            isA<FlashcardFailure>().having(
              (e) => e.message,
              'message',
              'No suitable content.',
            ),
          ),
        );
        expect(service.fetchFlashcardsCalled, isFalse);
      },
    );

    test(
      'failure: an unreachable Worker (network error) fails before '
      'Firestore is ever written to',
      () async {
        final mock = MockClient(
          (request) async => throw Exception('network down'),
        );
        final service = _TestFlashcardService(
          httpClient: mock,
          materials: [_material],
        );

        await expectLater(
          service.retake(
            sessionId: 'session-1',
            materialIds: ['m1'],
            difficulties: [DifficultyLevel.medium],
            count: 5,
          ),
          throwsA(isA<WorkerUnreachableException>()),
        );
        expect(service.fetchFlashcardsCalled, isFalse);
      },
    );

    test(
      'failure: a non-200 Worker response fails before Firestore is ever '
      'written to',
      () async {
        final mock = MockClient((request) async => http.Response('{}', 500));
        final service = _TestFlashcardService(
          httpClient: mock,
          materials: [_material],
        );

        await expectLater(
          service.retake(
            sessionId: 'session-1',
            materialIds: ['m1'],
            difficulties: [DifficultyLevel.medium],
            count: 5,
          ),
          throwsA(isA<WorkerResponseException>()),
        );
        expect(service.fetchFlashcardsCalled, isFalse);
      },
    );
  });
}
