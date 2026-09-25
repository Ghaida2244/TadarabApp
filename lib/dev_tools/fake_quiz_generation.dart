import '../models/enums.dart';
import '../services/quiz_generation_client.dart';

/// DEV-ONLY SWITCH.
///
/// When `true`, [QuizSessionService] (see quiz_session_service.dart) uses
/// [FakeQuizGenerationClient] instead of the real [QuizGenerationClient] —
/// no network call, no Worker, no Claude API, no cost. Every "Generate
/// quiz" tap in the running app returns realistic-looking sample questions
/// instantly, so the whole Quiz UI can be exercised and refined for free.
///
/// **Flip this back to `false` before testing against the real deployed
/// Worker again, and especially before testing the real integration with
/// Manar's Courses & Material upload feature** — real generation needs to
/// be re-verified before this feature is considered done.
const bool kUseFakeQuizGeneration = true;

/// Returns realistic-looking sample quiz items instantly — no HTTP call at
/// all (does not touch the network, the Worker, or Claude). Cycles through
/// a small hand-written bank so a request for more items than the bank
/// holds still returns something coherent rather than erroring.
class FakeQuizGenerationClient extends QuizGenerationClient {
  @override
  Future<GenerationResult> generateQuiz({
    required int count,
    required List<DifficultyLevel> difficulties,
    String? customPrompt,
    required List<GenerationMaterial> materials,
  }) async {
    final items = List.generate(count, (i) {
      final item = _bank[i % _bank.length];
      final difficulty = difficulties[i % difficulties.length];
      return GeneratedQuizItem(
        questionText: item.questionText,
        options: List.of(item.options),
        correctAnswer: item.correctAnswer,
        explanation: item.explanation,
        sourceLocation: item.sourceLocation,
        difficulty: difficulty,
      );
    });
    return GenerationResult(items: items, note: null);
  }
}

class _BankItem {
  const _BankItem({
    required this.questionText,
    required this.options,
    required this.correctAnswer,
    required this.explanation,
    required this.sourceLocation,
  });

  final String questionText;
  final List<String> options;
  final String correctAnswer;
  final String explanation;
  final String sourceLocation;
}

// Matches the topics in StubMaterialCatalog's seed materials, so a fake
// result still reads as plausibly grounded regardless of which stub
// material(s) were selected in Setup.
const List<_BankItem> _bank = [
  _BankItem(
    questionText: 'What is a database?',
    options: [
      'A collection of unrelated data',
      'A collection of related data',
      'A programming language',
      'A hardware device',
    ],
    correctAnswer: 'A collection of related data',
    explanation:
        'A database is a collection of related data representing some aspect of the real world, '
        'organised so it can be accessed, managed and updated.',
    sourceLocation: 'Lecture 1 — Introduction to Databases, Slide 1',
  ),
  _BankItem(
    questionText: 'What sits between the user (or an application) and the stored data?',
    options: ['A DBMS', 'The CPU', 'The router', 'The operating system'],
    correctAnswer: 'A DBMS',
    explanation:
        'A Database Management System (DBMS) is the software layer between users/applications '
        'and the stored data — every read and write passes through it.',
    sourceLocation: 'Lecture 1 — Introduction to Databases, Slide 2',
  ),
  _BankItem(
    questionText: 'Which of these is NOT an advantage of the database approach?',
    options: [
      'Controlled redundancy',
      'Shared access',
      'Data independence',
      'Guaranteed lower hardware cost',
    ],
    correctAnswer: 'Guaranteed lower hardware cost',
    explanation:
        'Centralising data controls redundancy and enables sharing and independence, but it '
        'usually needs more capable hardware, not less.',
    sourceLocation: 'Lecture 1 — Introduction to Databases, Slide 3',
  ),
  _BankItem(
    questionText: 'A schema describes…',
    options: [
      'The current rows in a table',
      'The structure and constraints of the data',
      'The physical disk layout only',
      'A single query result',
    ],
    correctAnswer: 'The structure and constraints of the data',
    explanation:
        'The schema is the description of structure and constraints; the rows that satisfy it at '
        'a moment in time are the instance.',
    sourceLocation: 'Lecture 1 — Introduction to Databases, Slide 4',
  ),
  _BankItem(
    questionText: 'What does photosynthesis produce, besides glucose?',
    options: ['Oxygen', 'Nitrogen', 'Carbon dioxide', 'Methane'],
    correctAnswer: 'Oxygen',
    explanation:
        'Photosynthesis uses sunlight, water, and carbon dioxide to produce glucose and oxygen, '
        'mainly in the chloroplasts of plant cells.',
    sourceLocation: 'Lecture 2 — Photosynthesis, Paragraph 1',
  ),
  _BankItem(
    questionText: 'Where do the light-independent reactions (the Calvin cycle) occur?',
    options: ['The stroma', 'The thylakoid membrane', 'The nucleus', 'The cell wall'],
    correctAnswer: 'The stroma',
    explanation:
        'The light-dependent reactions occur in the thylakoid membrane; the light-independent '
        'reactions (Calvin cycle) occur in the stroma.',
    sourceLocation: 'Lecture 2 — Photosynthesis, Paragraph 2',
  ),
];
