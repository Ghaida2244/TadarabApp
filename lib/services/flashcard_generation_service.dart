import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/enums.dart';
import '../models/study_material.dart';
import 'auth_service.dart';
import 'generation_topics.dart';

/// Thrown by [FlashcardGenerationService.generateFlashcards] when the Worker
/// is unreachable (no response at all — offline, timeout, DNS failure).
/// Distinct from a response the Worker did send back with an error, so the
/// Setup screen can show the network-failure message specifically for this
/// case.
class WorkerUnreachableException implements Exception {}

/// Thrown by [FlashcardGenerationService.generateFlashcards] when the Worker
/// responded but with a non-200 status. Carries the raw body so a future
/// caller could log/debug it, though the UI only ever shows the
/// generic-failure message for this case per CLAUDE.md.
class WorkerResponseException implements Exception {
  WorkerResponseException(this.statusCode, this.body);

  final int statusCode;
  final Map<String, dynamic>? body;
}

/// Thrown by [FlashcardGenerationService.generateFlashcards] on a retake
/// (`isRetake: true`) when at least one of the session's materials no
/// longer exists — stops before any generation request is sent.
class SessionMaterialDeletedException implements Exception {}

/// True when at least one of [materialIds] is missing from
/// [existingMaterialIds] — the material was deleted since the session was
/// created. Shared by the retake check above and
/// flashcard_sessions_screen.dart's session-card label, so both always
/// agree.
bool sessionHasDeletedMaterial(
  List<String> materialIds,
  Set<String> existingMaterialIds,
) => materialIds.any((id) => !existingMaterialIds.contains(id));

/// One generated flashcard, as returned by the Worker's `items` array.
class FlashcardGenerationItem {
  FlashcardGenerationItem({
    required this.frontText,
    required this.backText,
    required this.sourceLocation,
    required this.difficulty,
  });

  final String frontText;
  final String backText;
  final String sourceLocation;
  final DifficultyLevel difficulty;

  factory FlashcardGenerationItem.fromJson(Map<String, dynamic> json) {
    return FlashcardGenerationItem(
      frontText: json['frontText'] as String,
      backText: json['backText'] as String,
      sourceLocation: json['sourceLocation'] as String,
      difficulty: DifficultyLevelJson.fromJson(json['difficulty'] as String),
    );
  }
}

/// The Worker's successful `/generate` response for `type: "flashcard"`.
/// [note] mirrors the Quiz feature's [GenerationResult.note] — the Worker
/// sends one on every response type (fewer items than requested, or some
/// grounding-check discards), meant to be shown to the student directly
/// rather than treated as an error. [requestedCount] is the count the
/// caller asked for, carried alongside [items] so a screen can tell
/// whether generation fell short without needing to keep its own copy.
class FlashcardGenerationResult {
  FlashcardGenerationResult({
    required this.items,
    required this.requestedCount,
    this.note,
    this.coveredTopics = const [],
  });

  final List<FlashcardGenerationItem> items;
  final int requestedCount;
  final String? note;

  /// Short topic strings the Worker reports this batch actually covered —
  /// stored on the session so a future retake of it can send them back as
  /// `previousTopics`. Empty if the Worker's response omitted it.
  final List<String> coveredTopics;
}

/// Calls the deployed Cloudflare Worker's `POST /generate` (type:
/// "flashcard") to turn selected materials + settings into AI-generated
/// flashcards — the flashcard-side counterpart of [QuizGenerationService]
/// (quiz_generation_service.dart), calling the same deployed Worker and
/// endpoint, which already handles `type: "flashcard"` requests identically
/// to `type: "quiz"` ones (same generation.js, branches on `type`
/// throughout).
///
/// Unlike [QuizGenerationService.generateQuiz], which takes already-fetched
/// materials, this class doesn't own a materials fetch of its own — it's
/// handed one via [fetchMaterials], injected by [FlashcardSessionService]
/// (flashcard_session_service.dart), the only class that constructs this
/// one. That keeps the one source of "the course's materials" on the
/// session service (shared with its own non-generation callers, e.g. the
/// Setup screen's multi-select) without duplicating the Firestore read
/// here.
class FlashcardGenerationService {
  FlashcardGenerationService({
    required this.fetchMaterials,
    http.Client? httpClient,
    Future<String?> Function()? idTokenProvider,
    Uri? endpoint,
  }) : _httpClient = httpClient ?? http.Client(),
       _idTokenProvider = idTokenProvider ?? AuthService().getIdToken,
       _endpoint =
           endpoint ??
           Uri.parse('https://tadarab-ai-worker.tadarab.workers.dev/generate');

  /// Resolves the current course's materials — injected from
  /// [FlashcardSessionService.fetchMaterials] so there's one source for
  /// that Firestore read, shared with the Setup screen's own direct calls
  /// to it.
  final Future<List<StudyMaterial>> Function() fetchMaterials;

  final http.Client _httpClient;

  /// Resolves the caller's Firebase ID token for the Worker's
  /// Authorization: Bearer header. Defaults to [AuthService.getIdToken] —
  /// overridable so tests never need a real Firebase app to exercise the
  /// HTTP layer (same pattern as [QuizGenerationService]'s
  /// `idTokenProvider`, in quiz_generation_service.dart).
  final Future<String?> Function() _idTokenProvider;
  final Uri _endpoint;

  /// Calls the Cloudflare Worker's `POST /generate` (type: "flashcard") —
  /// the same deployed Worker and endpoint Quiz's [QuizGenerationService]
  /// calls (see quiz_generation_service.dart), which already handles
  /// `type: "flashcard"` requests identically to `type: "quiz"` ones (same
  /// generation.js, branches on `type` throughout). Re-fetches this
  /// course's materials (via [fetchMaterials]) to get each selected one's
  /// real `extractedText`, rather than requiring the caller to pass full
  /// [StudyMaterial] objects through — [FlashcardSetupScreen] already calls
  /// this with just [materialIds], and changing that call site wasn't
  /// needed.
  ///
  /// Throws [WorkerUnreachableException] (no response at all — offline,
  /// timeout, DNS failure, or no signed-in user to get a token from) or
  /// [WorkerResponseException] (the Worker responded, but not with a
  /// usable 200) — never a raw exception, so the Setup screen's existing
  /// `on WorkerUnreachableException` / generic `catch` both work correctly.
  /// [isRetake] tells the Worker this is a retake of a previous attempt
  /// with the same settings, same as [QuizGenerationService.generateQuiz] —
  /// see [FlashcardSessionService.retake], its only caller that passes
  /// `true`.
  Future<FlashcardGenerationResult> generateFlashcards({
    required List<String> materialIds,
    required List<DifficultyLevel> difficulties,
    required int count,
    String? customPrompt,
    bool isRetake = false,
    List<String> previousTopics = const [],
  }) async {
    final allMaterials = await fetchMaterials();
    final materials = allMaterials
        .where((m) => materialIds.contains(m.materialId))
        .toList();

    // Stop here, before generating anything, if this is a retake and a
    // material was deleted.
    if (isRetake &&
        sessionHasDeletedMaterial(
          materialIds,
          allMaterials.map((m) => m.materialId).toSet(),
        )) {
      throw SessionMaterialDeletedException();
    }

    String? token;
    try {
      token = await _idTokenProvider();
    } catch (_) {
      token = null;
    }
    if (token == null) {
      // No signed-in user to get a token from — can't even attempt the
      // call. Practically unreachable (the whole app requires sign-in
      // before this screen exists), but guarded the same way Quiz's
      // QuizGenerationService.generateQuiz guards it, for the same reason:
      // fail locally instead of sending an obviously-invalid request.
      throw WorkerUnreachableException();
    }

    http.Response response;
    try {
      response = await _httpClient
          .post(
            _endpoint,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'type': 'flashcard',
              'count': count,
              'difficulty': difficulties.map((d) => d.toJson()).toList(),
              if (customPrompt != null && customPrompt.trim().isNotEmpty)
                'customPrompt': customPrompt.trim(),
              'materials': [
                for (final m in materials)
                  {'title': m.title, 'sourceText': m.extractedText},
              ],
              'isRetake': isRetake,
              if (isRetake && previousTopics.isNotEmpty)
                'previousTopics': previousTopics,
            }),
          )
          .timeout(const Duration(seconds: 120));
    } catch (_) {
      throw WorkerUnreachableException();
    }

    Map<String, dynamic>? body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      body = null;
    }

    if (response.statusCode != 200 || body == null || body['items'] is! List) {
      throw WorkerResponseException(response.statusCode, body);
    }

    final items = (body['items'] as List)
        .map(
          (raw) => FlashcardGenerationItem.fromJson(raw as Map<String, dynamic>),
        )
        .toList();

    return FlashcardGenerationResult(
      items: items,
      requestedCount: count,
      note: body['note'] as String?,
      coveredTopics: parseCoveredTopics(body['coveredTopics']),
    );
  }
}
