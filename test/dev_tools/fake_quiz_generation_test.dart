import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/dev_tools/fake_quiz_generation.dart';
import 'package:tadarab_app/models/enums.dart';
import 'package:tadarab_app/services/quiz_generation_client.dart';

void main() {
  final client = FakeQuizGenerationClient();
  final materials = [
    GenerationMaterial(title: 'Lecture 1', sourceText: '[Slide 1]\n...'),
  ];

  test('normal case: returns exactly the requested count, instantly, no network', () async {
    final result = await client.generateQuiz(
      count: 5,
      difficulties: [DifficultyLevel.medium],
      materials: materials,
    );

    expect(result.items, hasLength(5));
    expect(result.note, isNull);
    for (final item in result.items) {
      expect(item.options, hasLength(4));
      expect(item.options, contains(item.correctAnswer));
      expect(item.questionText, isNotEmpty);
      expect(item.explanation, isNotEmpty);
      expect(item.sourceLocation, isNotEmpty);
    }
  });

  test('edge case: a count larger than the sample bank still returns that many items', () async {
    final result = await client.generateQuiz(
      count: 20,
      difficulties: [DifficultyLevel.easy],
      materials: materials,
    );

    expect(result.items, hasLength(20));
  });

  test('edge case: zero requested returns zero items, not an error', () async {
    final result = await client.generateQuiz(
      count: 0,
      difficulties: [DifficultyLevel.easy],
      materials: materials,
    );

    expect(result.items, isEmpty);
  });

  test('multi-select difficulty: items are tagged across the requested levels', () async {
    final result = await client.generateQuiz(
      count: 4,
      difficulties: [DifficultyLevel.easy, DifficultyLevel.hard],
      materials: materials,
    );

    final usedLevels = result.items.map((i) => i.difficulty).toSet();
    expect(usedLevels, {DifficultyLevel.easy, DifficultyLevel.hard});
  });
}
