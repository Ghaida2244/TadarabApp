import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../models/enums.dart';
import 'generation_topics.dart';

/// One material's title + the text sent to the generation Worker as its
/// content. [sourceText] is expected to already carry the Worker's
/// `[Slide N]` / `[Heading: Name]` / `[Paragraph N]`-style location tags —
/// see quiz_flashcard_generation_spec.md.
class GenerationMaterial {
  GenerationMaterial({required this.title, required this.sourceText});

  final String title;
  final String sourceText;

  Map<String, dynamic> toJson() => {'title': title, 'sourceText': sourceText};
}

/// One generated quiz item, as returned by the Worker (already grounding-
/// checked and option-shuffled server-side — see worker/src/index.js).
class GeneratedQuizItem {
  GeneratedQuizItem({
    required this.questionText,
    required this.options,
    required this.correctAnswer,
    required this.explanation,
    required this.sourceLocation,
    required this.difficulty,
  });

  final String questionText;
  final List<String> options;
  final String correctAnswer;
  final String explanation;
  final String sourceLocation;
  final DifficultyLevel difficulty;

  factory GeneratedQuizItem.fromJson(Map<String, dynamic> json) {
    return GeneratedQuizItem(
      questionText: json['questionText'] as String,
      options: List<String>.from(json['options'] as List),
      correctAnswer: json['correctAnswer'] as String,
      explanation: json['explanation'] as String,
      sourceLocation: json['sourceLocation'] as String,
      difficulty: DifficultyLevelJson.fromJson(json['difficulty'] as String),
    );
  }
}

/// A generation response: the items actually produced (which may be fewer
/// than requested — never padded, per CLAUDE.md) plus an optional [note]
/// explaining why, meant to be shown to the student directly rather than a
/// generic error.
class GenerationResult {
  GenerationResult({required this.items, this.note, this.coveredTopics = const []});

  final List<GeneratedQuizItem> items;
  final String? note;

  /// Short topic strings the Worker reports this batch actually covered —
  /// stored on the session so a future retake of it can send them back as
  /// `previousTopics`. Empty if the Worker's response omitted it.
  final List<String> coveredTopics;
}

/// A generation request failed (network error, not signed in, Worker/Claude
/// error, timeout, malformed response). [message] is an internal/debug
/// detail only — never shown to the student directly, since it may carry
/// a raw Worker/HTTP message (status codes, validation text meant for an
/// API caller, not a 16+ student). [isUnreachable] is the one thing the
/// caller needs to pick the right user-facing text: true only for "the
/// Worker could not be reached at all" (network/timeout/DNS), which maps
/// to [QuizSessionService]'s `kQuizNetworkFailureMessage`; false for every
/// other case (non-200, malformed body, not signed in), which maps to
/// `kQuizGenericFailureMessage`. Mirrors how Flashcards' generation layer
/// signals the same two buckets via two distinct exception types
/// ([WorkerUnreachableException]/[WorkerResponseException] in
/// flashcard_generation_service.dart) — kept as one class with a flag here
/// instead, since `GenerationFailure` already existed with callers relying
/// on its name.
class GenerationFailure implements Exception {
  GenerationFailure(this.message, {this.isUnreachable = false});

  final String message;
  final bool isUnreachable;

  @override
  String toString() => message;
}

/// Calls the deployed Cloudflare Worker's `POST /generate` to turn selected
/// materials + settings into AI-generated quiz questions. The Worker (not
/// this client) holds the Claude API key, verifies the caller's Firebase ID
/// token, builds the prompt, forces structured output, shuffles option
/// order, and runs the grounding check — this class is a thin, testable
/// wrapper around that HTTP call.
class QuizGenerationService {
  QuizGenerationService({
    http.Client? httpClient,
    Future<String?> Function()? idTokenProvider,
    Uri? endpoint,
  }) : _httpClient = httpClient ?? http.Client(),
       _idTokenProvider = idTokenProvider ?? _defaultIdTokenProvider,
       _endpoint =
           endpoint ??
           Uri.parse('https://tadarab-ai-worker.tadarab.workers.dev/generate');

  final http.Client _httpClient;

  /// Resolves the caller's Firebase ID token; overridable so tests never
  /// need a real Firebase app just to exercise the HTTP layer. Defaults to
  /// the real signed-in user's token.
  final Future<String?> Function() _idTokenProvider;
  final Uri _endpoint;

  static Future<String?> _defaultIdTokenProvider() {
    return FirebaseAuth.instance.currentUser?.getIdToken() ??
        Future.value(null);
  }

  /// Requests up to [count] quiz items from [materials] at the requested
  /// [difficulties] (at least one), with an optional [customPrompt] (already
  /// expected to be ≤300 characters — the Flutter field enforces that; the
  /// Worker re-checks it as a backup). [isRetake] tells the Worker this is a
  /// retake of a previous attempt with the same settings, so its prompt can
  /// ask Claude to vary phrasing/examples rather than repeat the same set —
  /// see [QuizSessionService.retakeSession], its only caller that passes
  /// `true`.
  ///
  /// [previousTopics] is only ever meaningfully sent when [isRetake] is
  /// true and non-empty — the retake's source session's own stored
  /// `coveredTopics` (see `buildPreviousTopics` in generation_topics.dart).
  ///
  /// Every failure throws [GenerationFailure] with [GenerationFailure
  /// .isUnreachable] set correctly for the caller to pick a user-facing
  /// message from — see that class's doc comment. No raw Worker/HTTP text
  /// (status codes, validation messages meant for an API caller) is ever
  /// carried in a way that reaches the student.
  Future<GenerationResult> generateQuiz({
    required int count,
    required List<DifficultyLevel> difficulties,
    String? customPrompt,
    required List<GenerationMaterial> materials,
    bool isRetake = false,
    List<String> previousTopics = const [],
  }) async {
    final String token;
    try {
      final idToken = await _idTokenProvider();
      if (idToken == null) {
        throw GenerationFailure('Not signed in.');
      }
      token = idToken;
    } on GenerationFailure {
      rethrow;
    } catch (_) {
      throw GenerationFailure('Could not verify sign-in.');
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
              'type': 'quiz',
              'count': count,
              'difficulty': difficulties.map((d) => d.toJson()).toList(),
              if (customPrompt != null && customPrompt.trim().isNotEmpty)
                'customPrompt': customPrompt.trim(),
              'materials': materials.map((m) => m.toJson()).toList(),
              'isRetake': isRetake,
              if (isRetake && previousTopics.isNotEmpty)
                'previousTopics': previousTopics,
            }),
          )
          .timeout(const Duration(seconds: 120));
    } catch (_) {
      throw GenerationFailure(
        'Could not reach the Worker.',
        isUnreachable: true,
      );
    }

    Map<String, dynamic>? body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      body = null;
    }

    // The Worker's own `message` (if any) is never shown here — it's
    // written for an API caller debugging the request shape (e.g. `"type"
    // must be one of quiz, flashcard`), not phrased for a student. See
    // [GenerationFailure]'s doc comment.
    if (response.statusCode != 200) {
      throw GenerationFailure(
        'Worker returned ${response.statusCode}.',
      );
    }
    if (body == null || body['items'] is! List) {
      throw GenerationFailure('Worker returned an unexpected response.');
    }

    final items = (body['items'] as List)
        .map((raw) => GeneratedQuizItem.fromJson(raw as Map<String, dynamic>))
        .toList();

    return GenerationResult(
      items: items,
      note: body['note'] as String?,
      coveredTopics: parseCoveredTopics(body['coveredTopics']),
    );
  }
}
