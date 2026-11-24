import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tadarab_app/models/enums.dart';
import 'package:tadarab_app/models/study_material.dart';
import 'package:tadarab_app/services/flashcard_generation_service.dart';

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
        'coveredTopics': ?coveredTopics,
      }),
      200,
    );

FlashcardGenerationService _service({
  required http.Client httpClient,
  List<StudyMaterial> materials = const [],
}) {
  return FlashcardGenerationService(
    fetchMaterials: () async => materials,
    httpClient: httpClient,
    idTokenProvider: () async => 'fake-token',
    endpoint: Uri.parse('https://example.test/generate'),
  );
}

void main() {
  group('generateFlashcards: isRetake', () {
    test('normal: sends isRetake: true in the request body when passed', () async {
      Map<String, dynamic>? capturedBody;
      final mock = MockClient((request) async {
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return _emptyItemsResponse();
      });
      final service = _service(httpClient: mock, materials: [_material]);

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
      final service = _service(httpClient: mock, materials: [_material]);

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
        final service = _service(httpClient: mock, materials: [_material]);

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
        final service = _service(httpClient: mock, materials: [_material]);

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
        final service = _service(httpClient: mock, materials: [_material]);

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

  group('generateFlashcards: deleted-material check on retake', () {
    test(
      'all materials deleted on a retake: throws before sending any request',
      () async {
        var requestSent = false;
        final mock = MockClient((request) async {
          requestSent = true;
          return _emptyItemsResponse();
        });
        final service = _service(httpClient: mock, materials: const []);

        await expectLater(
          service.generateFlashcards(
            materialIds: ['m1'],
            difficulties: [DifficultyLevel.medium],
            count: 5,
            isRetake: true,
          ),
          throwsA(isA<SessionMaterialDeletedException>()),
        );
        expect(requestSent, isFalse);
      },
    );

    test(
      'only one of several materials deleted on a retake: still throws '
      'before sending any request',
      () async {
        var requestSent = false;
        final mock = MockClient((request) async {
          requestSent = true;
          return _emptyItemsResponse();
        });
        // Only 'm1' survives; 'm2' is gone.
        final service = _service(httpClient: mock, materials: [_material]);

        await expectLater(
          service.generateFlashcards(
            materialIds: ['m1', 'm2'],
            difficulties: [DifficultyLevel.medium],
            count: 5,
            isRetake: true,
          ),
          throwsA(isA<SessionMaterialDeletedException>()),
        );
        expect(requestSent, isFalse);
      },
    );

    test('no materials deleted on a retake: the request is sent normally', () async {
      var requestSent = false;
      final mock = MockClient((request) async {
        requestSent = true;
        return _emptyItemsResponse();
      });
      final service = _service(httpClient: mock, materials: [_material]);

      await service.generateFlashcards(
        materialIds: ['m1'],
        difficulties: [DifficultyLevel.medium],
        count: 5,
        isRetake: true,
      );

      expect(requestSent, isTrue);
    });

    test(
      'a fresh (non-retake) generation is never blocked by this check, '
      'even with a "missing" material',
      () async {
        var requestSent = false;
        final mock = MockClient((request) async {
          requestSent = true;
          return _emptyItemsResponse();
        });
        final service = _service(httpClient: mock, materials: const []);

        await service.generateFlashcards(
          materialIds: ['m1'],
          difficulties: [DifficultyLevel.medium],
          count: 5,
          // isRetake defaults to false.
        );

        expect(requestSent, isTrue);
      },
    );
  });

  group('sessionHasDeletedMaterial', () {
    test('true when every materialId is missing', () {
      expect(sessionHasDeletedMaterial(['m1', 'm2'], {}), isTrue);
    });

    test('true when only one of several materialIds is missing', () {
      expect(
        sessionHasDeletedMaterial(['m1', 'm2', 'm3'], {'m1', 'm2'}),
        isTrue,
      );
    });

    test('false when every materialId still exists', () {
      expect(
        sessionHasDeletedMaterial(['m1', 'm2'], {'m1', 'm2', 'm3'}),
        isFalse,
      );
    });

    test('false for a session with no materials at all', () {
      expect(sessionHasDeletedMaterial([], {'m1'}), isFalse);
    });
  });

  group('generateFlashcards: coveredTopics parsing', () {
    test('normal: reads coveredTopics from the response', () async {
      final mock = MockClient(
        (request) async => _emptyItemsResponse(
          coveredTopics: ['Normalization', 'ACID'],
        ),
      );
      final service = _service(httpClient: mock, materials: [_material]);

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
      final service = _service(httpClient: mock, materials: [_material]);

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
      final service = _service(httpClient: mock, materials: [_material]);

      final result = await service.generateFlashcards(
        materialIds: ['m1'],
        difficulties: [DifficultyLevel.medium],
        count: 5,
      );

      expect(result.coveredTopics, isEmpty);
    });
  });
}
