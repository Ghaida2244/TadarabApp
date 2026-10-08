import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tadarab_app/models/enums.dart';
import 'package:tadarab_app/models/flashcard.dart';
import 'package:tadarab_app/models/study_material.dart';
import 'package:tadarab_app/services/flashcard_service.dart';

/// A [FlashcardService] with its two Firestore-*read* methods swapped for
/// canned data, so [generateFlashcards]/[retake]'s real Worker-calling and
/// request-body logic can be exercised with a mocked [http.Client] — no
/// real Firestore needed for anything these tests check. [retake]'s
/// Firestore *write* path (`_firestore.batch()...commit()`, reached only
/// once the Worker returns a non-empty result) is never exercised here —
/// there's no fake Firestore available in this project (confirmed: no such
/// package is even a dependency) — so every test below deliberately stays
/// on the side of that line where the real behavior is still being
/// exercised for real: an empty or failing Worker response, which
/// `retake()` must reject before ever touching Firestore.
class _TestFlashcardService extends FlashcardService {
  _TestFlashcardService({
    required http.Client httpClient,
    this.materials = const [],
  }) : super(
         uid: 'uid-1',
         courseId: 'course-1',
         httpClient: httpClient,
         idTokenProvider: () async => 'fake-token',
         endpoint: Uri.parse('https://example.test/generate'),
       );

  final List<StudyMaterial> materials;

  /// Set true the moment `fetchFlashcards` runs — the first step of
  /// `retake()`'s Firestore side, so "false" after a failed `retake()` call
  /// is this file's proof that Firestore was never touched. Every test here
  /// deliberately stays on the side of that line where the Worker response
  /// itself fails or returns zero items, so this never actually needs to
  /// return real card data — see the class doc comment above.
  bool fetchFlashcardsCalled = false;

  @override
  Future<List<StudyMaterial>> fetchMaterials() async => materials;

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

http.Response _emptyItemsResponse({String? note}) => http.Response(
  jsonEncode({'items': <dynamic>[], 'note': note}),
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
      'failure: a zero-item Worker response is rejected before Firestore '
      'is ever touched',
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
      'Firestore is ever touched',
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
      'touched',
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
