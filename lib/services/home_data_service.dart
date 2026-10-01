import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/calendar_event.dart';
import '../models/course.dart';
import '../models/flashcard_session.dart';
import '../models/question.dart';
import '../models/quiz_session.dart';
import '../models/student.dart';
import 'streak_service.dart' show dateOnly;

/// Quiz or flashcard — used wherever code needs to know which kind of
/// session/collection it's dealing with without duplicating logic per type.
enum SessionKind { quiz, flashcard }

/// Combined questions + flashcards studied (i.e. from *committed* sessions
/// only — see the "nothing counted until a session completes" rule) on one
/// calendar day.
class DailyStudyCount {
  DailyStudyCount({
    required this.date,
    this.questionCount = 0,
    this.flashcardCount = 0,
  });

  /// Local calendar date (time-of-day discarded).
  final DateTime date;
  final int questionCount;
  final int flashcardCount;

  int get combined => questionCount + flashcardCount;

  DailyStudyCount addQuestions(int count) => DailyStudyCount(
    date: date,
    questionCount: questionCount + count,
    flashcardCount: flashcardCount,
  );

  DailyStudyCount addFlashcards(int count) => DailyStudyCount(
    date: date,
    questionCount: questionCount,
    flashcardCount: flashcardCount + count,
  );
}

/// The current calendar week's (Sunday-start) daily study counts, for the
/// Today's Progress card's weekly row and its today-only question/flashcard
/// split.
class WeeklyProgress {
  WeeklyProgress({required this.weekStart, required this.days})
    : assert(days.length == 7);

  /// Sunday of the displayed week, local date-only.
  final DateTime weekStart;

  /// Sunday..Saturday, index 0..6.
  final List<DailyStudyCount> days;

  DailyStudyCount dayForDate(DateTime date) {
    final offset = dateOnly(date).difference(weekStart).inDays;
    if (offset < 0 || offset > 6) {
      return DailyStudyCount(date: dateOnly(date));
    }
    return days[offset];
  }

  static WeeklyProgress empty(DateTime weekStart) {
    return WeeklyProgress(
      weekStart: weekStart,
      days: List.generate(
        7,
        (i) => DailyStudyCount(date: weekStart.add(Duration(days: i))),
      ),
    );
  }
}

/// An incomplete quiz or flashcard session to resume, with its course name
/// already resolved so the UI doesn't need a second lookup.
class InProgressSession {
  InProgressSession({
    required this.sessionId,
    required this.kind,
    required this.courseId,
    required this.courseName,
    required this.currentIndex,
    required this.total,
    required this.resumePosition,
  });

  final String sessionId;
  final SessionKind kind;
  final String courseId;
  final String courseName;
  // Real answered/reviewed count (see _countAnsweredQuestions) — drives the
  // "X of Y answered" label and the progress bar fill. Deliberately *not*
  // the same value as resumePosition: a student can answer questions out
  // of the order they'll resume in (Exam mode allows paging back and
  // forth), so the two numbers can genuinely differ.
  final int currentIndex;
  final int total;
  // 1-based question/card number the Resume button will actually land on
  // — mirrors the Quiz Sessions screen's own `currentQuestionIndex + 1`,
  // not the answered count.
  final int resumePosition;
}

/// A calendar event with its course name already resolved (if it has one),
/// for the Upcoming section.
class UpcomingEventView {
  UpcomingEventView({required this.event, this.courseName});

  final CalendarEvent event;
  final String? courseName;
}

/// Sunday (local date-only) of the week containing [now].
DateTime startOfWeek(DateTime now) {
  final today = dateOnly(now);
  // DateTime.weekday: Monday=1 .. Sunday=7; days since Sunday = weekday % 7.
  return today.subtract(Duration(days: today.weekday % 7));
}

/// Folds a list of per-session activity entries into the 7-day array for
/// [weekStart]'s week. Pure — entries outside the week are ignored, which
/// lets callers pass a slightly-too-wide query result without filtering
/// first.
WeeklyProgress aggregateWeeklyProgress({
  required DateTime weekStart,
  required List<({DateTime date, int questionCount, int flashcardCount})>
  entries,
}) {
  final days = List.generate(
    7,
    (i) => DailyStudyCount(date: weekStart.add(Duration(days: i))),
  );
  for (final entry in entries) {
    final offset = dateOnly(entry.date).difference(weekStart).inDays;
    if (offset < 0 || offset > 6) continue;
    days[offset] = days[offset]
        .addQuestions(entry.questionCount)
        .addFlashcards(entry.flashcardCount);
  }
  return WeeklyProgress(weekStart: weekStart, days: days);
}

/// Firestore-backed data for the Home screen. Injectable (like
/// [AuthService]) so widget tests can supply canned results for every state
/// instead of needing a real Firestore.
class HomeDataService {
  HomeDataService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestoreOverride = firestore,
      _authOverride = auth;

  final FirebaseFirestore? _firestoreOverride;
  final FirebaseAuth? _authOverride;

  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

  String? get currentUid => _auth.currentUser?.uid;

  Stream<Student?> watchStudent(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return Student.fromFirestore(doc);
    });
  }

  Future<WeeklyProgress> fetchWeeklyProgress(
    String uid, {
    DateTime? now,
  }) async {
    final weekStart = startOfWeek(now ?? DateTime.now());
    final weekEnd = weekStart.add(const Duration(days: 7));
    final usersRef = _firestore.collection('users').doc(uid);

    final quizSnap = await usersRef
        .collection('quizSessions')
        .where('isSessionCompleted', isEqualTo: true)
        .where(
          'completedAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart),
        )
        .where('completedAt', isLessThan: Timestamp.fromDate(weekEnd))
        .get();
    final flashcardSnap = await usersRef
        .collection('flashcardSessions')
        .where('isSessionCompleted', isEqualTo: true)
        .where(
          'completedAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart),
        )
        .where('completedAt', isLessThan: Timestamp.fromDate(weekEnd))
        .get();

    final entries = <({DateTime date, int questionCount, int flashcardCount})>[
      for (final quiz in quizSnap.docs.map(QuizSession.fromFirestore))
        (
          date: quiz.completedAt!,
          questionCount: quiz.numberOfQuestions,
          flashcardCount: 0,
        ),
      for (final flashcard in flashcardSnap.docs.map(
        FlashcardSession.fromFirestore,
      ))
        (
          date: flashcard.completedAt!,
          questionCount: 0,
          flashcardCount: flashcard.numberOfFlashcards,
        ),
    ];

    return aggregateWeeklyProgress(weekStart: weekStart, entries: entries);
  }

  /// The most recently created incomplete session (quiz or flashcard), if
  /// any. Always null today, since nothing creates sessions yet (Phase C).
  Future<InProgressSession?> fetchInProgressSession(String uid) async {
    final usersRef = _firestore.collection('users').doc(uid);

    final quizSnap = await usersRef
        .collection('quizSessions')
        .where('isSessionCompleted', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();
    final flashcardSnap = await usersRef
        .collection('flashcardSessions')
        .where('isSessionCompleted', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    QuizSession? quiz = quizSnap.docs.isEmpty
        ? null
        : QuizSession.fromFirestore(quizSnap.docs.first);
    FlashcardSession? flashcard = flashcardSnap.docs.isEmpty
        ? null
        : FlashcardSession.fromFirestore(flashcardSnap.docs.first);

    if (quiz == null && flashcard == null) return null;

    final useQuiz =
        flashcard == null ||
        (quiz != null && quiz.createdAt.isAfter(flashcard.createdAt));
    if (useQuiz) {
      final courseName = await _courseName(uid, quiz!.courseId);
      // currentQuestionIndex only advances on "Next" (see the Quiz
      // Sessions screen's own "X of N answered" fix) — it undercounts a
      // question the student has answered but not yet moved past. Count
      // real answers instead, same fix, same reason, just a second
      // display of the same underlying data. It's still the right value
      // for resumePosition below, though — that one genuinely means "the
      // question the student will land on", not "how many they've
      // answered".
      final answered = await _countAnsweredQuestions(uid, quiz.sessionId);
      return InProgressSession(
        sessionId: quiz.sessionId,
        kind: SessionKind.quiz,
        courseId: quiz.courseId,
        courseName: courseName,
        currentIndex: answered,
        total: quiz.numberOfQuestions,
        resumePosition: quiz.currentQuestionIndex + 1,
      );
    }
    final courseName = await _courseName(uid, flashcard.courseId);
    return InProgressSession(
      sessionId: flashcard.sessionId,
      kind: SessionKind.flashcard,
      courseId: flashcard.courseId,
      courseName: courseName,
      // Flashcards & Sessions (feature/flashcards) isn't built yet, so
      // there's no per-card "reviewed" write to count the same way quiz
      // answers are counted above — currentFlashcardIndex is the best
      // available number today. Revisit once that feature defines its
      // own real "reviewed" concept.
      currentIndex: flashcard.currentFlashcardIndex,
      total: flashcard.numberOfFlashcards,
      resumePosition: flashcard.currentFlashcardIndex + 1,
    );
  }

  /// Number of questions in [sessionId] that actually have a
  /// [Question.studentAnswer] set — mirrors
  /// `QuizSessionService.countAnsweredQuestions`. Kept as its own query
  /// here (rather than a shared call into QuizSessionService) since
  /// HomeDataService takes an explicit [uid] and isn't scoped to
  /// `FirebaseAuth.currentUser` the way QuizSessionService is.
  Future<int> _countAnsweredQuestions(String uid, String sessionId) async {
    final snap = await _firestore
        .collection('users')
        .doc(uid)
        .collection('quizSessions')
        .doc(sessionId)
        .collection('questions')
        .get();
    return snap.docs
        .map(Question.fromFirestore)
        .where((q) => q.studentAnswer != null)
        .length;
  }

  Future<String> _courseName(String uid, String courseId) async {
    final doc = await _firestore
        .collection('users')
        .doc(uid)
        .collection('courses')
        .doc(courseId)
        .get();
    if (!doc.exists) return 'Unknown course';
    return Course.fromFirestore(doc).courseName;
  }

  Future<List<Course>> fetchCourses(String uid) async {
    final snap = await _firestore
        .collection('users')
        .doc(uid)
        .collection('courses')
        .get();
    return snap.docs.map(Course.fromFirestore).toList();
  }

  /// Upcoming events from today onward, soonest first.
  Future<List<UpcomingEventView>> fetchUpcomingEvents(
    String uid, {
    DateTime? now,
    int limit = 5,
  }) async {
    final today = dateOnly(now ?? DateTime.now());
    final snap = await _firestore
        .collection('users')
        .doc(uid)
        .collection('events')
        .where('eventDate', isGreaterThanOrEqualTo: Timestamp.fromDate(today))
        .orderBy('eventDate')
        .limit(limit)
        .get();

    final events = snap.docs.map(CalendarEvent.fromFirestore).toList();
    final views = <UpcomingEventView>[];
    for (final event in events) {
      final courseName = event.courseId == null
          ? null
          : await _courseName(uid, event.courseId!);
      views.add(UpcomingEventView(event: event, courseName: courseName));
    }
    return views;
  }
}
