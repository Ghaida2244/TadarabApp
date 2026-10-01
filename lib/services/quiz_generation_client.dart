import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../models/enums.dart';

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
  GenerationResult({required this.items, this.note});

  final List<GeneratedQuizItem> items;
  final String? note;
}

/// A generation request failed in a way the student should be told about
/// (network error, not signed in, Worker/Claude error, timeout). [message]
/// is written to be shown directly in the UI.
class GenerationFailure implements Exception {
  GenerationFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Calls the deployed Cloudflare Worker's `POST /generate` to turn selected
/// materials + settings into AI-generated quiz questions. The Worker (not
/// this client) holds the Claude API key, verifies the caller's Firebase ID
/// token, builds the prompt, forces structured output, shuffles option
/// order, and runs the grounding check — this class is a thin, testable
/// wrapper around that HTTP call.
class QuizGenerationClient {
  QuizGenerationClient({
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
  /// Worker re-checks it as a backup).
  Future<GenerationResult> generateQuiz({
    required int count,
    required List<DifficultyLevel> difficulties,
    String? customPrompt,
    required List<GenerationMaterial> materials,
  }) async {
    final String token;
    try {
      final idToken = await _idTokenProvider();
      if (idToken == null) {
        throw GenerationFailure('You need to be signed in to generate a quiz.');
      }
      token = idToken;
    } on GenerationFailure {
      rethrow;
    } catch (_) {
      throw GenerationFailure('Could not verify your sign-in — please try again.');
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
            }),
          )
          .timeout(const Duration(seconds: 45));
    } catch (_) {
      throw GenerationFailure(
        'Could not reach the quiz generator. Check your connection and try again.',
      );
    }

    Map<String, dynamic>? body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      body = null;
    }

    if (response.statusCode != 200) {
      final message = body?['message'] as String?;
      throw GenerationFailure(
        message ?? 'The quiz generator returned an error (${response.statusCode}). Please try again.',
      );
    }
    if (body == null || body['items'] is! List) {
      throw GenerationFailure('The quiz generator returned an unexpected response. Please try again.');
    }

    final items = (body['items'] as List)
        .map((raw) => GeneratedQuizItem.fromJson(raw as Map<String, dynamic>))
        .toList();

    return GenerationResult(items: items, note: body['note'] as String?);
  }
}
