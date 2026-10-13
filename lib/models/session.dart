import 'package:cloud_firestore/cloud_firestore.dart';

import 'enums.dart';

/// Shared fields for a study session (quiz or flashcard). Not a Firestore
/// collection of its own — QuizSession and FlashcardSession each store these
/// fields directly on their own documents (users/{uid}/quizSessions/... and
/// users/{uid}/flashcardSessions/...), per the Firestore schema in CLAUDE.md.
///
/// SessionMaterial (session-to-material) is likewise not a separate
/// collection: [materialIds] holds that relationship as a plain list.
abstract class Session {
  Session({
    required this.sessionId,
    required this.createdAt,
    this.completedAt,
    this.earnedPoints = 0,
    this.isSessionCompleted = false,
    required this.difficultyLevels,
    this.customPrompt,
    required this.email,
    required this.courseId,
    required this.materialIds,
    String? rootSessionId,
    this.retakeNumber = 0,
    this.retakeOfSessionId,
    this.coveredTopics = const [],
  }) : rootSessionId = rootSessionId ?? sessionId,
       assert(
         difficultyLevels.isNotEmpty,
         'difficultyLevels must have at least one entry',
       );

  /// Firestore document ID.
  final String sessionId;

  /// When the session was created.
  final DateTime createdAt;

  /// When the session was completed; null while still in progress.
  final DateTime? completedAt;

  /// Points earned in this session.
  final int earnedPoints;

  /// Whether the session has been completed.
  final bool isSessionCompleted;

  /// Difficulty/difficulties requested for this session's generated content.
  final List<DifficultyLevel> difficultyLevels;

  /// Optional custom prompt supplied by the student for generation.
  final String? customPrompt;

  /// Owning student's email (foreign key to Student).
  final String email;

  /// Course this session's materials belong to (foreign key to Course).
  final String courseId;

  /// IDs of the StudyMaterial documents this session was generated from.
  final List<String> materialIds;

  /// The original session's own id — every retake of it (and the original
  /// itself) shares this value, so they can be grouped without a
  /// `rootSessionId`-aware Firestore query. Defaults to [sessionId] when not
  /// given, which is exactly correct for a brand-new original session.
  final String rootSessionId;

  /// 0 for the original session, 1/2/3/... for each successive retake of
  /// it — see [sessionRetakeLabel].
  final int retakeNumber;

  /// The session this one was retaken from; null for an original session.
  final String? retakeOfSessionId;

  /// Short topic strings the Worker reported this session's generated
  /// content actually covered — sent back as `previousTopics` on a future
  /// retake of this same session (see [FlashcardService.retake] /
  /// [QuizSessionService.retakeSession]) so the Worker can vary phrasing
  /// instead of repeating itself. Empty for a session generated before this
  /// field existed.
  final List<String> coveredTopics;

  /// Shared fields common to both QuizSession and FlashcardSession documents.
  /// Subclasses spread this into their own toFirestore() map.
  Map<String, dynamic> sharedFieldsToFirestore() {
    return {
      'createdAt': Timestamp.fromDate(createdAt),
      'completedAt': completedAt == null
          ? null
          : Timestamp.fromDate(completedAt!),
      'earnedPoints': earnedPoints,
      'isSessionCompleted': isSessionCompleted,
      'difficultyLevels': difficultyLevels.map((d) => d.toJson()).toList(),
      'customPrompt': customPrompt,
      'email': email,
      'courseId': courseId,
      'materialIds': materialIds,
      'rootSessionId': rootSessionId,
      'retakeNumber': retakeNumber,
      'retakeOfSessionId': retakeOfSessionId,
      'coveredTopics': coveredTopics,
    };
  }
}

/// "Original" for the first session in a retake chain, "Retake N" for every
/// session retaken from it — the small label shown on each session card now
/// that a Retake creates a new session instead of overwriting the old one.
/// Use [sessionCardRetakeLabel] when actually deciding what (if anything)
/// to show on a session card — a plain [retakeNumber] of 0 alone doesn't
/// distinguish "the original of a chain with retakes" from "a session
/// that's never been retaken," which should show nothing at all.
String sessionRetakeLabel(int retakeNumber) =>
    retakeNumber == 0 ? 'Original' : 'Retake $retakeNumber';

/// The retake-chain label to show on [session]'s card within one screen's
/// currently-loaded [sessionsInList] — or null to show no label at all.
///
/// A retake (`retakeNumber > 0`) always shows [sessionRetakeLabel]. An
/// original (`retakeNumber == 0`) shows "Original" only if at least one
/// *other* session in [sessionsInList] shares its `rootSessionId` with
/// this session's own `sessionId` — i.e. it genuinely has a retake
/// currently loaded; an original with none shows nothing, and the label
/// disappears again on its own if every one of its retakes is later
/// deleted. Computed purely from already-loaded data, so this needs no new
/// query or index — every session already in the list the screen fetched
/// (via `courseId`) is a candidate, same as [nextRetakeNumber]'s own group
/// is computed from a `rootSessionId` query rather than a dedicated field.
///
/// An old session that predates `rootSessionId`/`retakeNumber` defaults to
/// `retakeNumber: 0` with `rootSessionId` equal to its own `sessionId` (see
/// [SessionFields.fromMap]) — i.e. it behaves exactly like a fresh,
/// never-retaken original here, and correctly shows nothing.
String? sessionCardRetakeLabel(
  Session session,
  Iterable<Session> sessionsInList,
) {
  if (session.retakeNumber > 0) return sessionRetakeLabel(session.retakeNumber);
  final hasRetakes = sessionsInList.any(
    (s) =>
        s.sessionId != session.sessionId &&
        s.rootSessionId == session.sessionId,
  );
  return hasRetakes ? 'Original' : null;
}

/// The `retakeNumber` a brand-new retake of this group should use — one
/// more than the highest `retakeNumber` already present, which always
/// includes the original (0) and every retake made from it so far.
/// [existingRetakeNumbersInGroup] is every session currently sharing the
/// same [Session.rootSessionId], including the one the student pressed
/// Retake on.
int nextRetakeNumber(Iterable<int> existingRetakeNumbersInGroup) {
  var highest = 0;
  for (final n in existingRetakeNumbersInGroup) {
    if (n > highest) highest = n;
  }
  return highest + 1;
}

/// Reads the fields shared by every Session subtype out of a document.
class SessionFields {
  SessionFields({
    required this.createdAt,
    required this.completedAt,
    required this.earnedPoints,
    required this.isSessionCompleted,
    required this.difficultyLevels,
    required this.customPrompt,
    required this.email,
    required this.courseId,
    required this.materialIds,
    required this.rootSessionId,
    required this.retakeNumber,
    required this.retakeOfSessionId,
    required this.coveredTopics,
  });

  final DateTime createdAt;
  final DateTime? completedAt;
  final int earnedPoints;
  final bool isSessionCompleted;
  final List<DifficultyLevel> difficultyLevels;
  final String? customPrompt;
  final String email;
  final String courseId;
  final List<String> materialIds;
  final String rootSessionId;
  final int retakeNumber;
  final String? retakeOfSessionId;
  final List<String> coveredTopics;

  /// [sessionId] is the document's own id (not read from [data]) — needed
  /// so an old document that predates `rootSessionId` can default it to
  /// its own id, per [Session.rootSessionId]'s doc comment.
  factory SessionFields.fromMap(Map<String, dynamic> data, {required String sessionId}) {
    return SessionFields(
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      earnedPoints: (data['earnedPoints'] as num?)?.toInt() ?? 0,
      isSessionCompleted: data['isSessionCompleted'] as bool? ?? false,
      difficultyLevels: _readDifficultyLevels(data),
      customPrompt: data['customPrompt'] as String?,
      email: data['email'] as String,
      courseId: data['courseId'] as String,
      materialIds: List<String>.from(data['materialIds'] as List? ?? const []),
      rootSessionId: data['rootSessionId'] as String? ?? sessionId,
      retakeNumber: (data['retakeNumber'] as num?)?.toInt() ?? 0,
      retakeOfSessionId: data['retakeOfSessionId'] as String?,
      coveredTopics: _readCoveredTopics(data),
    );
  }
}

/// Reads `coveredTopics` from a session document — an empty list for a
/// document that predates this field, or whose value isn't a list, rather
/// than throwing. Only `String` entries survive, same safety rule as
/// [parseCoveredTopics] (generation_topics.dart) applies to the Worker's
/// own response.
List<String> _readCoveredTopics(Map<String, dynamic> data) {
  final raw = data['coveredTopics'];
  if (raw is! List) return const [];
  return raw.whereType<String>().toList();
}

/// A safe stand-in for a session whose stored difficulty can't be read —
/// picked because it's the Setup screen's own default selection.
const List<DifficultyLevel> _fallbackDifficultyLevels = [DifficultyLevel.medium];

/// Reads `difficultyLevels` (current shape: a list) from a session document.
///
/// Never throws: an old document that predates this field (e.g. one
/// hand-created directly in the Firebase console before the
/// difficultyLevel -> difficultyLevels rename) may have it missing, empty,
/// or holding a value that no longer matches a [DifficultyLevel] — any of
/// those fall back to [_fallbackDifficultyLevels] instead of crashing the
/// whole screen that's reading this session. This is a display fallback,
/// not a fix for the document itself — a stored session showing "Medium"
/// this way should still be corrected or deleted at the data level.
List<DifficultyLevel> _readDifficultyLevels(Map<String, dynamic> data) {
  final raw = data['difficultyLevels'] as List?;
  if (raw == null || raw.isEmpty) return _fallbackDifficultyLevels;
  try {
    final parsed = raw
        .map((v) => DifficultyLevelJson.fromJson(v as String))
        .toList();
    return parsed.isEmpty ? _fallbackDifficultyLevels : parsed;
  } catch (_) {
    return _fallbackDifficultyLevels;
  }
}
