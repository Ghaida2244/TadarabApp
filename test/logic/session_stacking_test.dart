import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/logic/session_stacking.dart';

/// A minimal stand-in session for testing the generic grouping logic
/// without depending on either feature's real model.
class _FakeSession {
  _FakeSession({
    required this.id,
    required this.isCompleted,
    String? rootSessionId,
    this.retakeNumber = 0,
    required this.createdAt,
    this.completedAt,
  }) : rootSessionId = rootSessionId ?? id;

  final String id;
  final bool isCompleted;
  final String rootSessionId;
  final int retakeNumber;
  final DateTime createdAt;
  final DateTime? completedAt;
}

List<SessionStack<_FakeSession>> _group(List<_FakeSession> sessions) {
  return groupSessionsIntoStacks<_FakeSession>(
    sessions: sessions,
    isCompleted: (s) => s.isCompleted,
    rootSessionId: (s) => s.rootSessionId,
    retakeNumber: (s) => s.retakeNumber,
    createdAt: (s) => s.createdAt,
    completedAt: (s) => s.completedAt,
  );
}

void main() {
  group('groupSessionsIntoStacks', () {
    test('edge case: an empty list produces an empty result', () {
      expect(_group(const []), isEmpty);
    });

    test(
      'normal case: a lone session (no one else shares its root) renders '
      'as a single, non-stack group',
      () {
        final groups = _group([
          _FakeSession(id: 's1', isCompleted: true, createdAt: DateTime(2026, 1, 1)),
        ]);

        expect(groups, hasLength(1));
        expect(groups.single.isStack, isFalse);
        expect(groups.single.sessions, hasLength(1));
        expect(groups.single.top.id, 's1');
      },
    );

    test(
      'normal case: 2+ sessions sharing a root in the SAME section become '
      'one stack',
      () {
        final groups = _group([
          _FakeSession(
            id: 's1',
            isCompleted: true,
            createdAt: DateTime(2026, 1, 1),
            completedAt: DateTime(2026, 1, 1),
          ),
          _FakeSession(
            id: 's2',
            isCompleted: true,
            rootSessionId: 's1',
            retakeNumber: 1,
            createdAt: DateTime(2026, 1, 2),
            completedAt: DateTime(2026, 1, 2),
          ),
        ]);

        expect(groups, hasLength(1));
        expect(groups.single.isStack, isTrue);
        expect(groups.single.sessions, hasLength(2));
      },
    );

    test(
      'normal case: per-section separation — sessions sharing a root never '
      'mix an in-progress attempt with a completed one',
      () {
        final groups = _group([
          _FakeSession(
            id: 'original',
            isCompleted: true,
            createdAt: DateTime(2026, 1, 1),
            completedAt: DateTime(2026, 1, 1),
          ),
          _FakeSession(
            id: 'retake-in-progress',
            isCompleted: false,
            rootSessionId: 'original',
            retakeNumber: 1,
            createdAt: DateTime(2026, 1, 2),
          ),
        ]);

        // Same rootSessionId, but different sections -> two separate
        // single-session groups, neither a stack.
        expect(groups, hasLength(2));
        expect(groups.every((g) => !g.isStack), isTrue);
        expect(
          groups.map((g) => g.top.id).toSet(),
          {'original', 'retake-in-progress'},
        );
      },
    );

    test(
      'normal case: section order stays in-progress first, then completed',
      () {
        final groups = _group([
          _FakeSession(id: 'done', isCompleted: true, createdAt: DateTime(2026, 1, 1), completedAt: DateTime(2026, 1, 1)),
          _FakeSession(id: 'in-progress', isCompleted: false, createdAt: DateTime(2026, 1, 1)),
        ]);

        expect(groups.map((g) => g.isCompleted), [false, true]);
      },
    );

    test(
      'normal case: within a COMPLETED stack, latest first by completedAt '
      'descending',
      () {
        final groups = _group([
          _FakeSession(
            id: 'oldest',
            isCompleted: true,
            rootSessionId: 'root',
            retakeNumber: 0,
            createdAt: DateTime(2026, 1, 1),
            completedAt: DateTime(2026, 1, 1),
          ),
          _FakeSession(
            id: 'newest',
            isCompleted: true,
            rootSessionId: 'root',
            retakeNumber: 2,
            createdAt: DateTime(2026, 1, 3),
            completedAt: DateTime(2026, 1, 3),
          ),
          _FakeSession(
            id: 'middle',
            isCompleted: true,
            rootSessionId: 'root',
            retakeNumber: 1,
            createdAt: DateTime(2026, 1, 2),
            completedAt: DateTime(2026, 1, 2),
          ),
        ]);

        expect(groups.single.sessions.map((s) => s.id), [
          'newest',
          'middle',
          'oldest',
        ]);
      },
    );

    test(
      'edge case: a completed session missing completedAt falls back to '
      'createdAt for within-stack ordering',
      () {
        final groups = _group([
          _FakeSession(
            id: 'has-completedAt',
            isCompleted: true,
            rootSessionId: 'root',
            createdAt: DateTime(2026, 1, 1),
            completedAt: DateTime(2026, 1, 1),
          ),
          _FakeSession(
            id: 'no-completedAt-but-newer-created',
            isCompleted: true,
            rootSessionId: 'root',
            retakeNumber: 1,
            createdAt: DateTime(2026, 1, 5),
            // completedAt deliberately omitted (null).
          ),
        ]);

        expect(groups.single.sessions.map((s) => s.id), [
          'no-completedAt-but-newer-created',
          'has-completedAt',
        ]);
      },
    );

    test(
      'normal case: within an IN-PROGRESS stack, latest first by '
      'retakeNumber descending (not createdAt)',
      () {
        final groups = _group([
          _FakeSession(
            id: 'retake-1',
            isCompleted: false,
            rootSessionId: 'root',
            retakeNumber: 1,
            // Deliberately created AFTER retake-2, to prove retakeNumber
            // — not createdAt — decides order within an in-progress stack.
            createdAt: DateTime(2026, 1, 5),
          ),
          _FakeSession(
            id: 'retake-2',
            isCompleted: false,
            rootSessionId: 'root',
            retakeNumber: 2,
            createdAt: DateTime(2026, 1, 1),
          ),
        ]);

        expect(groups.single.sessions.map((s) => s.id), [
          'retake-2',
          'retake-1',
        ]);
      },
    );

    test(
      'edge case: within an IN-PROGRESS stack, equal retakeNumbers (should '
      'not normally happen) fall back to createdAt descending',
      () {
        final groups = _group([
          _FakeSession(
            id: 'older',
            isCompleted: false,
            rootSessionId: 'root',
            retakeNumber: 1,
            createdAt: DateTime(2026, 1, 1),
          ),
          _FakeSession(
            id: 'newer',
            isCompleted: false,
            rootSessionId: 'root',
            retakeNumber: 1,
            createdAt: DateTime(2026, 1, 3),
          ),
        ]);

        expect(groups.single.sessions.map((s) => s.id), ['newer', 'older']);
      },
    );

    test(
      'normal case: between groups, section order matches the pre-stacking '
      'criterion exactly — completed groups by their top attempt\'s '
      'completedAt descending, NOT retakeNumber-aware',
      () {
        final groups = _group([
          // Group A: a single completed session, completed LATER.
          _FakeSession(
            id: 'a',
            isCompleted: true,
            createdAt: DateTime(2026, 1, 1),
            completedAt: DateTime(2026, 1, 10),
          ),
          // Group B: a 2-attempt stack whose TOP (latest) completed
          // EARLIER than group A, despite having a higher retakeNumber.
          _FakeSession(
            id: 'b-original',
            isCompleted: true,
            rootSessionId: 'b',
            createdAt: DateTime(2026, 1, 1),
            completedAt: DateTime(2026, 1, 2),
          ),
          _FakeSession(
            id: 'b-retake',
            isCompleted: true,
            rootSessionId: 'b',
            retakeNumber: 1,
            createdAt: DateTime(2026, 1, 2),
            completedAt: DateTime(2026, 1, 3),
          ),
        ]);

        // Group A's completedAt (Jan 10) is later than group B's top
        // attempt's completedAt (Jan 3) -> A sorts first, even though B
        // has the higher retakeNumber.
        expect(groups.map((g) => g.top.id), ['a', 'b-retake']);
      },
    );

    test(
      'normal case: between IN-PROGRESS groups, section order is by '
      'createdAt descending only — NOT retakeNumber-aware, unchanged from '
      'before stacking existed',
      () {
        final groups = _group([
          // Group A: a single in-progress session, created LATER.
          _FakeSession(id: 'a', isCompleted: false, createdAt: DateTime(2026, 1, 10)),
          // Group B: a 2-attempt in-progress stack whose top (highest
          // retakeNumber) was created EARLIER than group A.
          _FakeSession(
            id: 'b-1',
            isCompleted: false,
            rootSessionId: 'b',
            retakeNumber: 1,
            createdAt: DateTime(2026, 1, 1),
          ),
          _FakeSession(
            id: 'b-2',
            isCompleted: false,
            rootSessionId: 'b',
            retakeNumber: 5,
            createdAt: DateTime(2026, 1, 2),
          ),
        ]);

        // Group A's createdAt (Jan 10) is later than group B's top
        // attempt's createdAt (Jan 2) -> A sorts first, even though B's
        // top has a much higher retakeNumber.
        expect(groups.map((g) => g.top.id), ['a', 'b-2']);
      },
    );

    test(
      'failure case: old sessions (default rootSessionId == own id, '
      'retakeNumber 0 — as if they predate these fields) each render as '
      'their own single card, never accidentally stacked together',
      () {
        final groups = _group([
          _FakeSession(id: 'old-1', isCompleted: true, createdAt: DateTime(2026, 1, 1), completedAt: DateTime(2026, 1, 1)),
          _FakeSession(id: 'old-2', isCompleted: true, createdAt: DateTime(2026, 1, 2), completedAt: DateTime(2026, 1, 2)),
        ]);

        expect(groups, hasLength(2));
        expect(groups.every((g) => !g.isStack), isTrue);
      },
    );

    test(
      'normal case: deleting an attempt down to one leaves a single, '
      'non-stack group (simulated by calling the grouping function again '
      'with the shrunk list, as the real screen does after a delete)',
      () {
        final beforeDelete = _group([
          _FakeSession(id: 'original', isCompleted: true, createdAt: DateTime(2026, 1, 1), completedAt: DateTime(2026, 1, 1)),
          _FakeSession(
            id: 'retake-1',
            isCompleted: true,
            rootSessionId: 'original',
            retakeNumber: 1,
            createdAt: DateTime(2026, 1, 2),
            completedAt: DateTime(2026, 1, 2),
          ),
        ]);
        expect(beforeDelete.single.isStack, isTrue);

        final afterDeletingRetake = _group([
          _FakeSession(id: 'original', isCompleted: true, createdAt: DateTime(2026, 1, 1), completedAt: DateTime(2026, 1, 1)),
        ]);

        expect(afterDeletingRetake.single.isStack, isFalse);
        expect(afterDeletingRetake.single.top.id, 'original');
      },
    );

    test('failure-adjacent: does not mutate the input list', () {
      final input = [
        _FakeSession(id: 'a', isCompleted: true, createdAt: DateTime(2026, 1, 1)),
        _FakeSession(id: 'b', isCompleted: true, createdAt: DateTime(2026, 1, 2)),
      ];
      _group(input);
      expect(input.map((s) => s.id).toList(), ['a', 'b']);
    });
  });

  group('SessionStack', () {
    test('asserts at least one session is given', () {
      expect(
        () => SessionStack<_FakeSession>(sessions: const [], isCompleted: true),
        throwsA(isA<AssertionError>()),
      );
    });

    test('top returns the first (latest) session', () {
      final a = _FakeSession(id: 'a', isCompleted: true, createdAt: DateTime(2026, 1, 1));
      final b = _FakeSession(id: 'b', isCompleted: true, createdAt: DateTime(2026, 1, 2));
      final stack = SessionStack<_FakeSession>(sessions: [a, b], isCompleted: true);
      expect(stack.top, a);
      expect(stack.isStack, isTrue);
    });
  });
}
