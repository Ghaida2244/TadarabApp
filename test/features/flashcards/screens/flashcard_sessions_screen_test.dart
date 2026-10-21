import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/features/flashcards/logic/flashcard_logic.dart';
import 'package:tadarab_app/features/flashcards/screens/flashcard_sessions_screen.dart';
import 'package:tadarab_app/models/enums.dart';
import 'package:tadarab_app/models/flashcard.dart';
import 'package:tadarab_app/models/flashcard_session.dart';
import 'package:tadarab_app/services/flashcard_service.dart';
import 'package:tadarab_app/theme/app_theme.dart';
import 'package:tadarab_app/widgets/app_button.dart';
import 'package:tadarab_app/widgets/generation_loading_overlay.dart';
import 'package:tadarab_app/widgets/scrollable_title_pill.dart';
import 'package:tadarab_app/widgets/session_stack_card.dart';
import 'package:tadarab_app/widgets/session_stack_focus_view.dart';

import '../../../helpers/fake_flashcard_service.dart';

AppButton _retakeButton(WidgetTester tester) => tester.widget<AppButton>(
  find.byWidgetPredicate(
    (w) => w is AppButton && w.label == 'Retake',
  ),
);

/// Matches a "RETAKE N" chain label pill specifically — not the "Retake"
/// button, which would otherwise make a plain
/// `find.textContaining('Retake')` ambiguous for this.
final Finder _retakeChainLabel = find.byWidgetPredicate(
  (w) => w is Text && RegExp(r'^RETAKE \d+$').hasMatch(w.data ?? ''),
);

List<Flashcard> _flashcards(int count, {String sessionId = 's1'}) =>
    List.generate(
      count,
      (i) => Flashcard(
        flashcardId: 'card-$i',
        frontText: 'Q$i',
        backText: 'A$i',
        reviewStatus: null,
        sourceLocation: 'Slide $i',
        sessionId: sessionId,
        cardIndex: i,
      ),
    );

FlashcardSession _session({
  required String id,
  required bool completed,
  int numberOfFlashcards = 10,
  int knownCount = 0,
  int needsReviewCount = 0,
  int currentFlashcardIndex = 0,
  List<String> materialTitles = const ['Lecture 1 - Introduction'],
  DateTime? createdAt,
  DateTime? completedAt,
  int retakeNumber = 0,
  String? rootSessionId,
  String? retakeOfSessionId,
}) {
  return FlashcardSession(
    sessionId: id,
    createdAt: createdAt ?? DateTime(2026, 1, 1),
    completedAt: completedAt,
    difficultyLevels: const [DifficultyLevel.easy],
    email: 'student@example.com',
    courseId: 'course-1',
    materialIds: const ['m1'],
    materialTitles: materialTitles,
    numberOfFlashcards: numberOfFlashcards,
    isSessionCompleted: completed,
    knownCount: knownCount,
    needsReviewCount: needsReviewCount,
    currentFlashcardIndex: currentFlashcardIndex,
    retakeNumber: retakeNumber,
    rootSessionId: rootSessionId,
    retakeOfSessionId: retakeOfSessionId,
  );
}

Widget _wrap(FakeFlashcardService service) {
  return MaterialApp(
    home: FlashcardSessionsScreen(
      uid: 'uid-1',
      courseId: 'course-1',
      email: 'student@example.com',
      service: service,
    ),
  );
}

void main() {
  testWidgets('empty state shows the no-sessions copy and hides the '
      'in-progress/completed sections', (tester) async {
    await tester.pumpWidget(_wrap(FakeFlashcardService(sessions: const [])));
    await tester.pumpAndSettle();

    expect(find.text('No sessions yet'), findsOneWidget);
    expect(
      find.textContaining('Turn a lecture into a deck'),
      findsOneWidget,
    );
    expect(find.text('IN PROGRESS'), findsNothing);
    expect(find.text('COMPLETED'), findsNothing);
    expect(find.text('0 sessions'), findsOneWidget);
    expect(find.text('Start new flashcards'), findsOneWidget);
  });

  testWidgets('a stream error shows the error state, not the empty state', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        FakeFlashcardService(
          sessions: const [],
          watchSessionsError: Exception('failed-precondition'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Couldn't load your sessions."), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('No sessions yet'), findsNothing);
  });

  testWidgets(
    'IN PROGRESS rows show newest-created first, and COMPLETED rows show '
    'most-recently-completed first',
    (tester) async {
      // IN PROGRESS: s2 (created later) must render above s1.
      final s1 = _session(
        id: 's1',
        completed: false,
        createdAt: DateTime(2026, 1, 1),
        currentFlashcardIndex: 0,
      );
      final s2 = _session(
        id: 's2',
        completed: false,
        createdAt: DateTime(2026, 3, 1),
        currentFlashcardIndex: 4,
      );
      // COMPLETED: s4 (completed later, despite an earlier createdAt) must
      // render above s3.
      final s3 = _session(
        id: 's3',
        completed: true,
        createdAt: DateTime(2025, 1, 1),
        completedAt: DateTime(2026, 1, 1),
        numberOfFlashcards: 10,
        knownCount: 3,
      );
      final s4 = _session(
        id: 's4',
        completed: true,
        createdAt: DateTime(2025, 1, 1),
        completedAt: DateTime(2026, 3, 1),
        numberOfFlashcards: 12,
        knownCount: 7,
      );

      await tester.pumpWidget(
        _wrap(FakeFlashcardService(sessions: [s1, s2, s3, s4])),
      );
      await tester.pump();
      await tester.pump();

      final s2Resume = tester.getTopLeft(find.text('Resume at card 5')).dy;
      final s1Resume = tester.getTopLeft(find.text('Resume at card 1')).dy;
      expect(
        s2Resume,
        lessThan(s1Resume),
        reason: 'the newer in-progress session (s2) should render above s1',
      );

      // The COMPLETED rows sit below both IN PROGRESS rows and may be
      // scrolled out of the default test viewport — bring them into view.
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pump();

      final s4Known = tester.getTopLeft(find.text('12 cards')).dy;
      final s3Known = tester.getTopLeft(find.text('10 cards')).dy;
      expect(
        s4Known,
        lessThan(s3Known),
        reason:
            'the more recently completed session (s4) should render above s3',
      );
    },
  );

  testWidgets('shows a singular session count for exactly one session', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        FakeFlashcardService(
          sessions: [_session(id: 's1', completed: false)],
        ),
      ),
    );
    // Not pumpAndSettle(): the row's default sample material title can be
    // wide enough to trigger the marquee's continuous (never-settling)
    // scroll — see the "material-title pill marquee" group below. This
    // test doesn't care about that; one frame is enough to see the text.
    await tester.pump();

    expect(find.text('1 session'), findsOneWidget);
  });

  testWidgets('an in-progress session shows the reviewed count and resume '
      'label', (tester) async {
    await tester.pumpWidget(
      _wrap(
        FakeFlashcardService(
          sessions: [
            _session(
              id: 's1',
              completed: false,
              numberOfFlashcards: 10,
              knownCount: 2,
              needsReviewCount: 1,
              currentFlashcardIndex: 3,
            ),
          ],
        ),
      ),
    );
    // Not pumpAndSettle() — see the note in the previous test.
    await tester.pump();

    expect(find.text('IN PROGRESS'), findsOneWidget);
    expect(find.text('3 of 10 reviewed'), findsOneWidget);
    expect(find.text('Resume at card 4'), findsOneWidget);
  });

  testWidgets('a completed session shows its known count and both action '
      'buttons', (tester) async {
    await tester.pumpWidget(
      _wrap(
        FakeFlashcardService(
          sessions: [
            _session(
              id: 's1',
              completed: true,
              numberOfFlashcards: 10,
              knownCount: 8,
            ),
          ],
        ),
      ),
    );
    // Not pumpAndSettle() — see the note above the singular-count test.
    await tester.pump();

    expect(find.text('COMPLETED'), findsOneWidget);
    expect(find.text('10 cards'), findsOneWidget);
    expect(find.text('Results'), findsOneWidget);
    expect(find.text('Retake'), findsOneWidget);
  });

  testWidgets(
    'the Results and Retake buttons on a completed session are equal width',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          FakeFlashcardService(
            sessions: [_session(id: 's1', completed: true)],
          ),
        ),
      );
      // Not pumpAndSettle() — see the note above the singular-count test.
      await tester.pump();

      final resultsWidth = tester
          .getSize(find.widgetWithText(AppButton, 'Results'))
          .width;
      final retakeWidth = tester
          .getSize(find.widgetWithText(AppButton, 'Retake'))
          .width;
      expect(resultsWidth, retakeWidth);
    },
  );

  testWidgets(
    'the in-progress Resume button sits 24dp from the card edges, '
    "narrower than the text content's 15dp inset",
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          FakeFlashcardService(
            sessions: [
              _session(
                id: 's1',
                completed: false,
                currentFlashcardIndex: 3,
              ),
            ],
          ),
        ),
      );
      // Not pumpAndSettle() — see the note above the singular-count test.
      await tester.pump();

      // The single Padding carrying the card's own 15dp content inset —
      // shared ancestor of both the text content and the button area, so
      // measuring against its rect isolates each one's own extra inset.
      final contentBox = find.byWidgetPredicate(
        (w) =>
            w is Padding &&
            w.padding == const EdgeInsets.fromLTRB(15, 15, 15, 19),
      );
      final contentRect = tester.getRect(contentBox);
      final titleRect = tester.getRect(find.byType(ScrollableTitlePill));
      final buttonRect = tester.getRect(
        find.widgetWithText(AppButton, 'Resume at card 4'),
      );

      expect(titleRect.left - contentRect.left, 15);
      expect(buttonRect.left - contentRect.left, 24);
      expect(contentRect.right - buttonRect.right, 24);
    },
  );

  testWidgets(
    'the Resume button, and the Results/Retake buttons, are 46dp tall',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          FakeFlashcardService(
            sessions: [
              _session(id: 's1', completed: true),
              _session(id: 's2', completed: false, currentFlashcardIndex: 3),
            ],
          ),
        ),
      );
      // Not pumpAndSettle() — see the note above the singular-count test.
      await tester.pump();

      expect(
        tester.widget<AppButton>(find.widgetWithText(AppButton, 'Results')).height,
        46,
      );
      expect(
        tester.widget<AppButton>(find.widgetWithText(AppButton, 'Retake')).height,
        46,
      );
      expect(
        tester
            .widget<AppButton>(
              find.widgetWithText(AppButton, 'Resume at card 4'),
            )
            .height,
        46,
      );
    },
  );

  group('retake label', () {
    testWidgets(
      'normal case: an original session that already has a loaded retake '
      'is labeled "Original" — both labels visible inside the resulting '
      "stack's focus view",
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            FakeFlashcardService(
              sessions: [
                _session(id: 's1', completed: true, retakeNumber: 0),
                _session(
                  id: 's2',
                  completed: true,
                  retakeNumber: 1,
                  rootSessionId: 's1',
                  retakeOfSessionId: 's1',
                ),
              ],
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        // Two completed attempts sharing a root now collapse into one
        // stack in the main list — open it to see both labels at once.
        // The list underneath stays mounted (just visually covered), so
        // these finders are scoped to inside the focus view specifically.
        expect(find.byType(SessionStackCard), findsOneWidget);
        await tester.tap(find.byType(SessionStackCard));
        await tester.pumpAndSettle();

        final focusView = find.byType(SessionStackFocusView);
        expect(focusView, findsOneWidget);
        expect(
          find.descendant(of: focusView, matching: find.text('ORIGINAL')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: focusView, matching: find.text('RETAKE 1')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'edge case: an original session with no retakes currently loaded '
      'shows no label at all',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            FakeFlashcardService(
              sessions: [
                _session(id: 's1', completed: true, retakeNumber: 0),
              ],
            ),
          ),
        );
        await tester.pump();

        expect(find.text('ORIGINAL'), findsNothing);
        expect(_retakeChainLabel, findsNothing);
      },
    );

    testWidgets('normal case: a session with retakeNumber 3 is labeled '
        '"Retake 3"', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FakeFlashcardService(
            sessions: [
              _session(id: 's1', completed: true, retakeNumber: 3),
            ],
          ),
        ),
      );
      await tester.pump();

      expect(find.text('RETAKE 3'), findsOneWidget);
      expect(find.text('ORIGINAL'), findsNothing);
    });

    testWidgets(
      'edge case: an old session (default rootSessionId/retakeNumber, as '
      'if it predates these fields) shows no label at all',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            FakeFlashcardService(
              sessions: [_session(id: 's1', completed: true)],
            ),
          ),
        );
        await tester.pump();

        expect(find.text('ORIGINAL'), findsNothing);
        expect(_retakeChainLabel, findsNothing);
      },
    );
  });

  group('Retake', () {
    testWidgets(
      'tapping Retake disables the button and shows the full-screen '
      'generating overlay until the Worker call resolves, then navigates',
      (tester) async {
        final pending = Completer<RetakeOutcome>();
        final service = FakeFlashcardService(
          sessions: [
            _session(id: 's1', completed: true, knownCount: 8),
          ],
          pendingRetake: pending,
          flashcardsBySessionId: {'s1': _flashcards(10)},
        );
        await tester.pumpWidget(_wrap(service));
        await tester.pump();

        expect(find.byType(GenerationLoadingOverlay), findsNothing);
        expect(_retakeButton(tester).onPressed, isNotNull);

        await tester.tap(find.text('Retake'));
        await tester.pump();

        expect(find.byType(GenerationLoadingOverlay), findsOneWidget);
        expect(_retakeButton(tester).onPressed, isNull);

        pending.complete((
          requestedCount: 10,
          actualCount: 10,
          note: null,
          newSessionId: 's1',
        ));
        await tester.pumpAndSettle();

        expect(
          find.byType(FlashcardSessionsScreen),
          findsNothing,
          reason: 'a successful retake navigates to the Flip Deck screen',
        );
      },
    );

    testWidgets(
      'a Retake failure shows a SnackBar, clears the generating overlay, '
      'and leaves the session in place',
      (tester) async {
        final service = FakeFlashcardService(
          sessions: [
            _session(id: 's1', completed: true, knownCount: 8),
          ],
          writeError: FlashcardFailure('Could not reach Tadarab.'),
        );
        await tester.pumpWidget(_wrap(service));
        await tester.pump();

        await tester.tap(find.text('Retake'));
        await tester.pump();
        await tester.pump();

        expect(find.text('Could not reach Tadarab.'), findsOneWidget);
        expect(find.byType(GenerationLoadingOverlay), findsNothing);
        expect(_retakeButton(tester).onPressed, isNotNull);
        expect(find.text('Retake'), findsOneWidget);
      },
    );
  });

  group('material-title pill sizing', () {
    // The hug-vs-scroll decision needs one extra pump after the first: the
    // available width is read from a RenderBox in a post-frame callback,
    // then a setState schedules the frame that may switch into scroll mode.

    testWidgets('a single short title hugs its content — no scroll view '
        'is introduced', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FakeFlashcardService(
            sessions: [
              _session(
                id: 's1',
                completed: false,
                materialTitles: const ['Lecture 1'],
              ),
            ],
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Lecture 1'), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsNothing);
    });

    testWidgets('a long joined material-title list becomes exactly the '
        'available width and is genuinely drag-scrollable — not wrapped, '
        'not truncated, and not silently left hugging a wider box', (
      tester,
    ) async {
      const titles = [
        'Lecture 1 - Introduction to Databases',
        'Lecture 2 - Requirements Engineering',
        'Lecture 3 - Entity Relationship Diagrams',
      ];
      await tester.pumpWidget(
        _wrap(
          FakeFlashcardService(
            sessions: [
              _session(id: 's1', completed: false, materialTitles: titles),
            ],
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      final joined = titles.join(', ');
      // Single line, not wrapped, not ellipsized.
      expect(find.text(joined), findsOneWidget);

      final scrollFinder = find.byType(SingleChildScrollView);
      expect(scrollFinder, findsOneWidget);
      expect(
        tester.widget<SingleChildScrollView>(scrollFinder).scrollDirection,
        Axis.horizontal,
      );

      // Genuinely draggable, not just present: a drag actually moves the
      // scroll position away from zero.
      final scrollableState = tester.state<ScrollableState>(
        find.descendant(
          of: scrollFinder,
          matching: find.byType(Scrollable),
        ),
      );
      expect(scrollableState.position.pixels, 0.0);

      await tester.drag(scrollFinder, const Offset(-80, 0));
      await tester.pump();

      expect(
        scrollableState.position.pixels,
        greaterThan(0.0),
        reason: 'Dragging the pill did not move its scroll position — it '
            "isn't actually scrollable.",
      );
    });
  });

  group('Retake Stacks: focus view', () {
    List<FlashcardSession> twoCompletedAttempts() => [
      _session(
        id: 'original',
        completed: true,
        retakeNumber: 0,
        knownCount: 6,
      ),
      _session(
        id: 'retake-1',
        completed: true,
        retakeNumber: 1,
        rootSessionId: 'original',
        retakeOfSessionId: 'original',
        knownCount: 8,
      ),
    ];

    List<FlashcardSession> twoInProgressAttempts() => [
      _session(
        id: 'original',
        completed: false,
        retakeNumber: 0,
        currentFlashcardIndex: 1,
      ),
      _session(
        id: 'retake-1',
        completed: false,
        retakeNumber: 1,
        rootSessionId: 'original',
        retakeOfSessionId: 'original',
        currentFlashcardIndex: 3,
      ),
    ];

    testWidgets('tapping a stack opens its focus view', (tester) async {
      await tester.pumpWidget(
        _wrap(FakeFlashcardService(sessions: twoCompletedAttempts())),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(SessionStackFocusView), findsNothing);
      await tester.tap(find.byType(SessionStackCard));
      await tester.pumpAndSettle();

      expect(find.byType(SessionStackFocusView), findsOneWidget);
      expect(find.text('2 attempts · Completed'), findsOneWidget);
    });

    testWidgets('the × button closes the focus view', (tester) async {
      await tester.pumpWidget(
        _wrap(FakeFlashcardService(sessions: twoCompletedAttempts())),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byType(SessionStackCard));
      await tester.pumpAndSettle();
      expect(find.byType(SessionStackFocusView), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.byType(SessionStackFocusView), findsNothing);
    });

    testWidgets('tapping the dimmed backdrop closes the focus view', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(FakeFlashcardService(sessions: twoCompletedAttempts())),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byType(SessionStackCard));
      await tester.pumpAndSettle();
      expect(find.byType(SessionStackFocusView), findsOneWidget);

      // Tap near the very top-left corner — outside the header/list
      // content, onto the dimmed backdrop itself.
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      expect(find.byType(SessionStackFocusView), findsNothing);
    });

    testWidgets(
      'every attempt inside the focus view has its own full card: Retake '
      'is present on completed attempts, and each has its own delete',
      (tester) async {
        await tester.pumpWidget(
          _wrap(FakeFlashcardService(sessions: twoCompletedAttempts())),
        );
        await tester.pump();
        await tester.pump();

        await tester.tap(find.byType(SessionStackCard));
        await tester.pumpAndSettle();

        final focusView = find.byType(SessionStackFocusView);
        expect(
          find.descendant(of: focusView, matching: find.text('Results')),
          findsNWidgets(2),
        );
        expect(
          find.descendant(of: focusView, matching: find.text('Retake')),
          findsNWidgets(2),
        );
        expect(
          find.descendant(
            of: focusView,
            matching: find.byIcon(Icons.delete_outline),
          ),
          findsNWidgets(2),
        );
      },
    );

    testWidgets(
      'deleting an attempt inside the focus view down to one closes it '
      'and leaves a plain card behind, keeping its own label',
      (tester) async {
        final service = FakeFlashcardService(
          sessions: twoCompletedAttempts(),
        );
        await tester.pumpWidget(_wrap(service));
        await tester.pump();
        await tester.pump();

        await tester.tap(find.byType(SessionStackCard));
        await tester.pumpAndSettle();

        final focusView = find.byType(SessionStackFocusView);
        await tester.tap(
          find
              .descendant(
                of: focusView,
                matching: find.byIcon(Icons.delete_outline),
              )
              .first,
        );
        await tester.pumpAndSettle();
        expect(find.text('Delete this session?'), findsOneWidget);
        await tester.tap(find.text('Delete session'));
        await tester.pumpAndSettle();

        expect(service.deleteSessionCalls, 1);
        // Down to one attempt: the live stream reflects the delete, the
        // focus view closes itself, and the remaining attempt renders as
        // a plain (non-stack) card.
        expect(find.byType(SessionStackFocusView), findsNothing);
        expect(find.byType(SessionStackCard), findsNothing);
        expect(find.textContaining('RETAKE'), findsOneWidget);
      },
    );

    testWidgets(
      "a plain in-progress card's Resume button uses the same compact "
      'metrics as Quiz\'s (46dp height, 12dp radius, 13sp font)',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            FakeFlashcardService(
              sessions: [_session(id: 's1', completed: false)],
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        final resumeButton = tester.widget<AppButton>(
          find.widgetWithText(AppButton, 'Resume at card 1'),
        );
        expect(resumeButton.height, 46);
        expect(resumeButton.borderRadius, 12);
        expect(resumeButton.fontSize, 13);
      },
    );

    testWidgets(
      "inside the focus view, an in-progress attempt's Resume button also "
      'uses the compact metrics',
      (tester) async {
        await tester.pumpWidget(
          _wrap(FakeFlashcardService(sessions: twoInProgressAttempts())),
        );
        await tester.pump();
        await tester.pump();

        await tester.tap(find.byType(SessionStackCard));
        await tester.pumpAndSettle();

        final focusView = find.byType(SessionStackFocusView);
        final resumeButtons = tester.widgetList<AppButton>(
          find.descendant(
            of: focusView,
            matching: find.byWidgetPredicate(
              (w) => w is AppButton && w.label.startsWith('Resume at card'),
            ),
          ),
        );
        expect(resumeButtons, hasLength(2));
        for (final button in resumeButtons) {
          expect(button.height, 46);
          expect(button.borderRadius, 12);
          expect(button.fontSize, 13);
        }
      },
    );

    testWidgets(
      'reduced motion: the stack and its focus view render without error',
      (tester) async {
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: _wrap(FakeFlashcardService(sessions: twoCompletedAttempts())),
          ),
        );
        await tester.pump();
        await tester.pump();
        expect(tester.takeException(), isNull);

        await tester.tap(find.byType(SessionStackCard));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(SessionStackFocusView), findsOneWidget);

        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(SessionStackFocusView), findsNothing);
      },
    );

    testWidgets('RTL: the stack and its focus view render without error', (
      tester,
    ) async {
      final service = FakeFlashcardService(sessions: twoCompletedAttempts());
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: FlashcardSessionsScreen(
              uid: 'uid-1',
              courseId: 'course-1',
              email: 'student@example.com',
              service: service,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull);

      await tester.tap(find.byType(SessionStackCard));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(SessionStackFocusView), findsOneWidget);
    });

    // Regression coverage for a real visual bug found on-device: the row's
    // own Container used to carry `margin: EdgeInsets.only(bottom: 12)` for
    // inter-card spacing (this screen used a plain ListView, not
    // ListView.separated). That margin became part of the exact widget
    // SessionStackCard measures to place its peek layers, so a stacked
    // top card's margin was silently absorbed into the peek's own reserved
    // space — the peek stuck out ~20dp instead of the design's 8dp, and the
    // "gap" before the next list item was entirely consumed by that
    // overshoot instead of ever being a real gap. Fixed by removing the
    // row's own margin and giving the list itself a uniform 12dp
    // `ListView.separated` gap (matching quiz_sessions_screen.dart exactly).
    testWidgets(
      "a stacked top card's peek layer sticks out exactly 8dp below the "
      'visible card, not inflated by the row content pushing into the '
      "stack's own reserved spacing",
      (tester) async {
        await tester.pumpWidget(
          _wrap(FakeFlashcardService(sessions: twoCompletedAttempts())),
        );
        await tester.pump();
        await tester.pump();

        final stack = find.byType(SessionStackCard);
        final peekLayer = find.descendant(
          of: stack,
          matching: find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.decoration is BoxDecoration &&
                (w.decoration as BoxDecoration).border?.top.color ==
                    AppColors.borderDefault,
          ),
        );
        final visibleCard = find.descendant(
          of: stack,
          matching: find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.decoration is BoxDecoration &&
                (w.decoration as BoxDecoration).border?.top.color ==
                    AppColors.cardTint,
          ),
        );
        expect(peekLayer, findsOneWidget);
        expect(visibleCard, findsOneWidget);

        final peekBottom = tester.getRect(peekLayer).bottom;
        final cardBottom = tester.getRect(visibleCard).bottom;
        expect(
          peekBottom - cardBottom,
          8,
          reason:
              'the peek layer should stick out exactly 8dp below the '
              'visible card (SessionStackCard.dc.html spec), not more — a '
              "row's own margin corrupting the stack's reserved-space math "
              'would inflate this.',
        );
      },
    );

    testWidgets(
      'the gap between a stack and the next card in the same section '
      "matches a plain card's own list gap (12dp) — the stack's peek "
      "reservation doesn't swallow the row's spacing",
      (tester) async {
        final sessions = [
          ...twoCompletedAttempts(),
          _session(
            id: 'lone',
            completed: true,
            createdAt: DateTime(2025, 12, 1),
            knownCount: 1,
            // A count distinct from twoCompletedAttempts' default (10), so
            // this card's own detail text is unambiguous to find.
            numberOfFlashcards: 7,
          ),
        ];
        await tester.pumpWidget(_wrap(FakeFlashcardService(sessions: sessions)));
        await tester.pump();
        await tester.pump();

        final stackBottom = tester.getRect(find.byType(SessionStackCard)).bottom;
        final loneCard = find.ancestor(
          of: find.text('7 cards'),
          matching: find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.decoration is BoxDecoration &&
                (w.decoration as BoxDecoration).border?.top.color ==
                    AppColors.cardTint,
          ),
        );
        expect(loneCard, findsOneWidget);
        final loneCardTop = tester.getRect(loneCard).top;

        expect(
          loneCardTop - stackBottom,
          12,
          reason:
              'the gap after a stack should be the same 12dp ListView.'
              'separated gap as every other item — not swallowed by the '
              "stack's own peek-layer reservation.",
        );
      },
    );
  });
}
