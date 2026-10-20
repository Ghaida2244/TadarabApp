import 'package:tadarab_app/models/course.dart';
import 'package:tadarab_app/models/student.dart';
import 'package:tadarab_app/services/home_data_service.dart';

/// A controllable stand-in for [HomeDataService] used across the Home
/// screen widget tests, so they never depend on a real Firestore. Every
/// field is a canned result the test configures up front.
class FakeHomeDataService extends HomeDataService {
  FakeHomeDataService({
    Student? student,
    WeeklyProgress? weeklyProgress,
    this.weeklyProgressByWeek = const {},
    this.weeklyProgressError,
    this.inProgress,
    this.courses = const [],
    this.upcomingEvents = const [],
  }) : student = student ?? _defaultStudent,
       weeklyProgress =
           weeklyProgress ?? WeeklyProgress.empty(startOfWeek(DateTime.now()));

  static final _defaultStudent = Student(
    uid: 'uid-1',
    email: 'student@example.com',
    name: 'Ghaida',
  );

  final Student? student;

  /// The fallback result for any week not explicitly keyed in
  /// [weeklyProgressByWeek] — including the current week, by default,
  /// exactly as before this field existed.
  final WeeklyProgress weeklyProgress;

  /// Per-week canned results, keyed by that week's Sunday — lets a test
  /// give an *earlier* week's streak-row page different data than the
  /// current week's, for the Today's Progress card's swipeable pager.
  final Map<DateTime, WeeklyProgress> weeklyProgressByWeek;

  /// When set, a `fetchWeeklyProgress` call for any week *not* explicitly
  /// keyed in [weeklyProgressByWeek] throws this instead of returning data
  /// — used to test the streak row's fetch-failure fallback (treat the
  /// week as empty) for an earlier week, without also breaking the
  /// current week's own (unrelated) initial load.
  final Object? weeklyProgressError;

  final InProgressSession? inProgress;

  /// Mutable so a test can simulate "a course was created elsewhere" by
  /// updating this between reloads, rather than being stuck with whatever
  /// was passed to the constructor for the fake's whole lifetime.
  List<Course> courses;
  final List<UpcomingEventView> upcomingEvents;

  int fetchCoursesCalls = 0;

  /// Every week Sunday `fetchWeeklyProgress` was actually called for, in
  /// call order — lets a test assert the streak row's pager fetches a
  /// given week exactly once (lazy loading + caching), not on every
  /// rebuild or every time the same page is revisited.
  final List<DateTime> fetchWeeklyProgressCalls = [];

  @override
  String? get currentUid => student?.uid;

  @override
  Stream<Student?> watchStudent(String uid) => Stream.value(student);

  @override
  Future<WeeklyProgress> fetchWeeklyProgress(
    String uid, {
    DateTime? now,
  }) async {
    final weekStart = startOfWeek(now ?? DateTime.now());
    fetchWeeklyProgressCalls.add(weekStart);
    if (weeklyProgressByWeek.containsKey(weekStart)) {
      return weeklyProgressByWeek[weekStart]!;
    }
    if (weeklyProgressError != null) throw weeklyProgressError!;
    return weeklyProgress;
  }

  @override
  Future<InProgressSession?> fetchInProgressSession(String uid) async =>
      inProgress;

  @override
  Future<List<Course>> fetchCourses(String uid) async {
    fetchCoursesCalls++;
    return courses;
  }

  @override
  Future<List<UpcomingEventView>> fetchUpcomingEvents(
    String uid, {
    DateTime? now,
    int limit = 5,
  }) async => upcomingEvents;
}
