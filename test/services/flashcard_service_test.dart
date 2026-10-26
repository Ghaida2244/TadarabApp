import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mock_exceptions/mock_exceptions.dart';
import 'package:tadarab_app/models/enums.dart';
import 'package:tadarab_app/models/flashcard.dart';
import 'package:tadarab_app/models/flashcard_session.dart';
import 'package:tadarab_app/models/study_material.dart';
import 'package:tadarab_app/services/flashcard_service.dart';
import 'package:tadarab_app/services/streak_service.dart';

/// A [FlashcardService] with its Firestore-*read* methods swapped for
/// canned data, so [generateFlashcards]/[retake]'s real Worker-calling and
/// request-body logic can be exercised with a mocked [http.Client] — no
/// real Firestore needed for anything these tests check. `retake()` now
/// reads the source session first (for its `coveredTopics`, to build
/// `previousTopics`) before calling the Worker — [fetchSession] is faked
/// here for exactly that read. Its Firestore *write* path
/// (`_firestore.batch()...commit()`, and the private `_fetchSessionsInGroup`
/// read just before it, both reached only once the Worker returns a
/// non-empty result) is never exercised here, since `_fetchSessionsInGroup`
/// is library-private so a test file can't override it the way it can
/// [fetchSession] — so every test below deliberately stays on the side of
/// that line where the real behavior is still being exercised for real: an
/// empty or failing Worker response, which `retake()` must reject before
/// ever writing to Firestore. (`fake_cloud_firestore` *is* now a dev
/// dependency — added for the Calendar feature — and is used directly
/// against the real `FlashcardService`, no subclass needed, in the
/// `completeSession` group below, since that method needs no Worker call
/// at all.)
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

  group('completeSession — points, rank and streak', () {
    late FakeFirebaseFirestore firestore;
    late FlashcardService service;

    DocumentReference<Map<String, dynamic>> studentDoc() =>
        firestore.collection('users').doc('uid-1');

    CollectionReference<Map<String, dynamic>> sessionsRef() =>
        studentDoc().collection('flashcardSessions');

    FlashcardSession flashcardSession(String id) => FlashcardSession(
      sessionId: id,
      createdAt: DateTime(2026, 1, 1),
      difficultyLevels: const [DifficultyLevel.medium],
      email: 'student@example.com',
      courseId: 'course-1',
      materialIds: const ['m1'],
      materialTitles: const ['Lecture 1'],
    );

    Future<void> seedStudent({int? totalPoints}) async {
      final data = <String, dynamic>{
        'email': 'student@example.com',
        'name': 'Student',
      };
      if (totalPoints != null) data['totalPoints'] = totalPoints;
      await studentDoc().set(data);
    }

    Future<void> seedSessionWithCard(
      FlashcardSession session,
      Flashcard card,
    ) async {
      final sessionRef = sessionsRef().doc(session.sessionId);
      await sessionRef.set(session.toFirestore());
      await sessionRef
          .collection('flashcards')
          .doc(card.flashcardId)
          .set(card.toFirestore());
    }

    setUp(() {
      firestore = FakeFirebaseFirestore();
      service = FlashcardService(
        uid: 'uid-1',
        courseId: 'course-1',
        firestore: firestore,
        streakService: StreakService(firestore: firestore),
      );
    });

    test(
      'normal case: completing a session calls the streak service exactly '
      'once (FIX 1 — Flashcards previously never advanced the streak)',
      () async {
        await seedStudent(totalPoints: 0);
        await seedSessionWithCard(
          flashcardSession('s1'),
          Flashcard(
            flashcardId: 'c1',
            frontText: 'Q',
            backText: 'A',
            reviewStatus: null,
            sourceLocation: 'Slide 1',
            sessionId: 's1',
            cardIndex: 0,
          ),
        );

        await service.completeSession(
          sessionId: 's1',
          flashcardId: 'c1',
          status: ReviewStatus.knowIt,
          finalIndex: 0,
          knownCount: 1,
          needsReviewCount: 0,
          completedAt: DateTime(2026, 3, 10),
        );

        final data = (await studentDoc().get()).data()!;
        expect(data['currentStreak'], 1);
        expect(data['lastStudyDate'], isNotNull);
      },
    );

    test(
      'edge case: markFlashcard (a non-final card) never touches the '
      'streak or totalPoints — only completeSession does',
      () async {
        await seedStudent(totalPoints: 0);
        await seedSessionWithCard(
          flashcardSession('s2'),
          Flashcard(
            flashcardId: 'c1',
            frontText: 'Q',
            backText: 'A',
            reviewStatus: null,
            sourceLocation: 'Slide 1',
            sessionId: 's2',
            cardIndex: 0,
          ),
        );

        await service.markFlashcard(
          sessionId: 's2',
          flashcardId: 'c1',
          status: ReviewStatus.needsReview,
          currentFlashcardIndex: 1,
          knownCount: 0,
          needsReviewCount: 1,
        );

        final data = (await studentDoc().get()).data()!;
        expect(data.containsKey('currentStreak'), isFalse);
        expect(data['totalPoints'], 0);
      },
    );

    test(
      'normal case: completeSession, just above a rank threshold — '
      'currentRank is updated to match the new total',
      () async {
        // Active Learner starts at 100; one known card is 2 points.
        await seedStudent(totalPoints: 98);
        await seedSessionWithCard(
          flashcardSession('s3'),
          Flashcard(
            flashcardId: 'c1',
            frontText: 'Q',
            backText: 'A',
            reviewStatus: null,
            sourceLocation: 'Slide 1',
            sessionId: 's3',
            cardIndex: 0,
          ),
        );

        await service.completeSession(
          sessionId: 's3',
          flashcardId: 'c1',
          status: ReviewStatus.knowIt,
          finalIndex: 0,
          knownCount: 1,
          needsReviewCount: 0,
          completedAt: DateTime(2026, 3, 10),
        );

        final data = (await studentDoc().get()).data()!;
        expect(data['totalPoints'], 100);
        expect(data['currentRank'], 'Active Learner');
      },
    );

    test(
      'edge case: completeSession, just below a rank threshold — '
      'currentRank stays at the current rank',
      () async {
        await seedStudent(totalPoints: 98);
        await seedSessionWithCard(
          flashcardSession('s4'),
          Flashcard(
            flashcardId: 'c1',
            frontText: 'Q',
            backText: 'A',
            reviewStatus: null,
            sourceLocation: 'Slide 1',
            sessionId: 's4',
            cardIndex: 0,
          ),
        );

        await service.completeSession(
          // No known cards: zero points, stays below 100.
          sessionId: 's4',
          flashcardId: 'c1',
          status: ReviewStatus.needsReview,
          finalIndex: 0,
          knownCount: 0,
          needsReviewCount: 1,
          completedAt: DateTime(2026, 3, 10),
        );

        final data = (await studentDoc().get()).data()!;
        expect(data['totalPoints'], 98);
        expect(data['currentRank'], 'Beginner Learner');
      },
    );

    test(
      'edge case: a student doc with no totalPoints field at all is '
      'treated as 0, not a crash',
      () async {
        await seedStudent(); // no totalPoints field
        await seedSessionWithCard(
          flashcardSession('s5'),
          Flashcard(
            flashcardId: 'c1',
            frontText: 'Q',
            backText: 'A',
            reviewStatus: null,
            sourceLocation: 'Slide 1',
            sessionId: 's5',
            cardIndex: 0,
          ),
        );

        await service.completeSession(
          sessionId: 's5',
          flashcardId: 'c1',
          status: ReviewStatus.knowIt,
          finalIndex: 0,
          knownCount: 1,
          needsReviewCount: 0,
          completedAt: DateTime(2026, 3, 10),
        );

        final data = (await studentDoc().get()).data()!;
        expect(data['totalPoints'], 2);
        expect(data['currentRank'], 'Beginner Learner');
      },
    );

    test(
      'failure case: a failed read of the student doc still saves the '
      'session and totalPoints, and skips currentRank entirely',
      () async {
        await seedStudent(totalPoints: 10);
        await seedSessionWithCard(
          flashcardSession('s6'),
          Flashcard(
            flashcardId: 'c1',
            frontText: 'Q',
            backText: 'A',
            reviewStatus: null,
            sourceLocation: 'Slide 1',
            sessionId: 's6',
            cardIndex: 0,
          ),
        );
        whenCalling(
          Invocation.method(#get, null),
        ).on(studentDoc()).thenThrow(FirebaseException(plugin: 'cloud_firestore'));
        // StreakService reads the very same student doc path right after
        // the completion batch commits — give it an entirely separate
        // Firestore so the registered failure above (which isn't scoped to
        // a single call) doesn't also break the unrelated streak write
        // this test isn't exercising.
        final serviceWithIsolatedStreak = FlashcardService(
          uid: 'uid-1',
          courseId: 'course-1',
          firestore: firestore,
          streakService: StreakService(firestore: FakeFirebaseFirestore()),
        );

        await serviceWithIsolatedStreak.completeSession(
          sessionId: 's6',
          flashcardId: 'c1',
          status: ReviewStatus.knowIt,
          finalIndex: 0,
          knownCount: 1,
          needsReviewCount: 0,
          completedAt: DateTime(2026, 3, 10),
        );

        // A plain studentDoc().get() (and even a collection-level query —
        // fake_cloud_firestore's own .get() fetches each matching document
        // via its own .get() internally) would hit the same registered
        // failure above, since it throws on every matching call, not just
        // the first. .snapshots() reads the current in-memory state
        // directly and isn't instrumented by mock_exceptions at all.
        final data = (await studentDoc().snapshots().first).data()!;
        expect(data['totalPoints'], 12);
        expect(data.containsKey('currentRank'), isFalse);
      },
    );
  });
}
