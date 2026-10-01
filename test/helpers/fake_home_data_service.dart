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
  final WeeklyProgress weeklyProgress;
  final InProgressSession? inProgress;

  /// Mutable so a test can simulate "a course was created elsewhere" by
  /// updating this between reloads, rather than being stuck with whatever
  /// was passed to the constructor for the fake's whole lifetime.
  List<Course> courses;
  final List<UpcomingEventView> upcomingEvents;

  int fetchCoursesCalls = 0;

  @override
  String? get currentUid => student?.uid;

  @override
  Stream<Student?> watchStudent(String uid) => Stream.value(student);

  @override
  Future<WeeklyProgress> fetchWeeklyProgress(
    String uid, {
    DateTime? now,
  }) async => weeklyProgress;

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
