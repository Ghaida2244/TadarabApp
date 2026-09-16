import { describe, test, expect } from 'vitest';
import {
  parseDifficulty,
  validateCustomPrompt,
  computeMaxTokens,
  buildSourceText,
  buildPrompt,
  buildToolSchema,
  shuffleArray,
  shuffleQuizOptions,
  MAX_CUSTOM_PROMPT_LENGTH,
  MODEL_MAX_OUTPUT_TOKENS,
} from '../src/generation.js';

describe('parseDifficulty', () => {
  test('normal: a single string level', () => {
    expect(parseDifficulty('easy')).toEqual(['easy']);
  });

  test('edge: a list with more than one level, case/whitespace tolerant, de-duplicated', () => {
    expect(parseDifficulty([' Easy ', 'HARD', 'easy'])).toEqual(['easy', 'hard']);
  });

  test('failure: missing entirely', () => {
    expect(() => parseDifficulty(undefined)).toThrow(/difficulty/i);
  });

  test('failure: an invalid level', () => {
    expect(() => parseDifficulty('impossible')).toThrow(/Invalid difficulty/);
  });

  test('failure: an empty list', () => {
    expect(() => parseDifficulty([])).toThrow(/at least one level/);
  });
});

describe('validateCustomPrompt', () => {
  test('normal: a short prompt passes', () => {
    expect(() => validateCustomPrompt('Focus on chapter 2.')).not.toThrow();
  });

  test('normal: absent/empty passes (customPrompt is optional)', () => {
    expect(() => validateCustomPrompt(null)).not.toThrow();
    expect(() => validateCustomPrompt('')).not.toThrow();
  });

  test('edge: exactly 300 characters passes', () => {
    expect(() => validateCustomPrompt('a'.repeat(MAX_CUSTOM_PROMPT_LENGTH))).not.toThrow();
  });

  test('failure: 301 characters is rejected', () => {
    expect(() => validateCustomPrompt('a'.repeat(MAX_CUSTOM_PROMPT_LENGTH + 1))).toThrow(/300 characters or fewer/);
  });

  test('failure: a non-string value is rejected', () => {
    expect(() => validateCustomPrompt(42)).toThrow(/must be a string/);
  });
});

describe('computeMaxTokens', () => {
  test('normal: quiz formula is 500 + count*350', () => {
    expect(computeMaxTokens('quiz', 10)).toBe(500 + 10 * 350);
  });

  test('normal: flashcard formula is 500 + count*200', () => {
    expect(computeMaxTokens('flashcard', 10)).toBe(500 + 10 * 200);
  });

  test('edge: a count large enough to hit the model cap is clamped, not left uncapped', () => {
    const uncapped = 500 + 1000 * 350;
    expect(uncapped).toBeGreaterThan(MODEL_MAX_OUTPUT_TOKENS);
    expect(computeMaxTokens('quiz', 1000)).toBe(MODEL_MAX_OUTPUT_TOKENS);
  });

  test('failure-adjacent: count=1 still produces a sane positive value', () => {
    expect(computeMaxTokens('quiz', 1)).toBe(850);
  });
});

describe('buildSourceText', () => {
  test('normal: one material gets a single [Material: title] header', () => {
    const text = buildSourceText([{ title: 'Lecture 1', sourceText: '[Slide 1]\nHello' }]);
    expect(text).toBe('[Material: Lecture 1]\n[Slide 1]\nHello');
  });

  test('edge: multiple materials are joined with a blank line between them', () => {
    const text = buildSourceText([
      { title: 'A', sourceText: 'content A' },
      { title: 'B', sourceText: 'content B' },
    ]);
    expect(text).toBe('[Material: A]\ncontent A\n\n[Material: B]\ncontent B');
  });
});

describe('buildPrompt', () => {
  const baseArgs = {
    type: 'quiz',
    count: 5,
    difficulties: ['easy'],
    customPrompt: null,
    materials: [{ title: 'Lecture 1', sourceText: '[Slide 1]\nSome content.' }],
  };

  test('normal: includes the count, type, and every required rule section', () => {
    const prompt = buildPrompt(baseArgs);
    expect(prompt).toContain('Generate up to 5 quiz items total');
    expect(prompt).toContain('CONTENT RULE (most important — overrides everything else):');
    expect(prompt).toContain('WORDING & LANGUAGE RULE:');
    expect(prompt).toContain('DIFFICULTY LEVELS REQUESTED: easy');
    expect(prompt).toContain('DISTRIBUTION RULE:');
    expect(prompt).toContain('MULTIPLE-MATERIAL RULE');
    expect(prompt).toContain('STUDENT INSTRUCTION HANDLING:');
    expect(prompt).toContain('SOURCE TEXT:');
    expect(prompt).toContain('[Material: Lecture 1]');
  });

  test('normal: quiz gets OPTIONS RULE and the full EXPLANATION RULE, not the flashcard sections', () => {
    const prompt = buildPrompt(baseArgs);
    expect(prompt).toContain('OPTIONS RULE (quiz only):');
    expect(prompt).toContain('EXPLANATION RULE:');
    expect(prompt).not.toContain('BACK TEXT SHAPE');
    expect(prompt).not.toContain('N/A for flashcards');
  });

  test('normal: flashcard gets BACK TEXT SHAPE and the N/A explanation note, not the quiz sections', () => {
    const prompt = buildPrompt({ ...baseArgs, type: 'flashcard' });
    expect(prompt).toContain('BACK TEXT SHAPE (flashcard only):');
    expect(prompt).toContain('EXPLANATION RULE: N/A for flashcards');
    expect(prompt).not.toContain('OPTIONS RULE');
  });

  test('edge: multiple requested difficulty levels each get their own definition line', () => {
    const prompt = buildPrompt({ ...baseArgs, difficulties: ['easy', 'hard'] });
    expect(prompt).toContain('DIFFICULTY LEVELS REQUESTED: easy, hard');
    expect(prompt).toContain('easy: Directly stated in the source');
    expect(prompt).toContain('hard: Requires analysis or connecting more than one concept');
    expect(prompt).not.toContain('medium:');
  });

  test('edge: a present customPrompt is included verbatim', () => {
    const prompt = buildPrompt({ ...baseArgs, customPrompt: 'Make it exam-style.' });
    expect(prompt).toContain("STUDENT'S ADDITIONAL INSTRUCTION: Make it exam-style.");
  });

  test('normal: an absent customPrompt omits that section entirely', () => {
    const prompt = buildPrompt(baseArgs);
    expect(prompt).not.toContain("STUDENT'S ADDITIONAL INSTRUCTION");
  });
});

describe('buildToolSchema', () => {
  test('normal: quiz schema requires exactly the quiz fields, no correctAnswer/options on flashcards', () => {
    const quizSchema = buildToolSchema('quiz');
    const itemSchema = quizSchema.input_schema.properties.items.items;
    expect(itemSchema.required).toEqual(['questionText', 'options', 'correctAnswer', 'explanation', 'sourceLocation', 'difficulty']);
    expect(itemSchema.properties.options.minItems).toBe(4);
    expect(itemSchema.properties.options.maxItems).toBe(4);
  });

  test('normal: flashcard schema has no options/correctAnswer at all', () => {
    const flashcardSchema = buildToolSchema('flashcard');
    const itemSchema = flashcardSchema.input_schema.properties.items.items;
    expect(itemSchema.required).toEqual(['frontText', 'backText', 'sourceLocation', 'difficulty']);
    expect(itemSchema.properties.options).toBeUndefined();
    expect(itemSchema.properties.correctAnswer).toBeUndefined();
  });

  test('edge: "note" is present but not required on both schemas', () => {
    for (const type of ['quiz', 'flashcard']) {
      const schema = buildToolSchema(type);
      expect(schema.input_schema.properties.note).toBeDefined();
      expect(schema.input_schema.required).toEqual(['items']);
    }
  });
});

describe('shuffleArray', () => {
  test('normal: result is a permutation of the same elements', () => {
    const input = ['a', 'b', 'c', 'd'];
    const result = shuffleArray(input);
    expect(result).toHaveLength(4);
    expect([...result].sort()).toEqual([...input].sort());
  });

  test('edge: does not mutate the input array', () => {
    const input = ['a', 'b', 'c', 'd'];
    const copy = [...input];
    shuffleArray(input);
    expect(input).toEqual(copy);
  });

  test('edge: a single-element array is returned unchanged', () => {
    expect(shuffleArray(['only'])).toEqual(['only']);
  });
});

describe('shuffleQuizOptions', () => {
  test("normal: correctAnswer text still matches one of the (reordered) options", () => {
    const items = [
      { questionText: 'Q1', options: ['A', 'B', 'C', 'D'], correctAnswer: 'C' },
      { questionText: 'Q2', options: ['W', 'X', 'Y', 'Z'], correctAnswer: 'W' },
    ];
    const shuffled = shuffleQuizOptions(items);
    for (let i = 0; i < items.length; i++) {
      expect([...shuffled[i].options].sort()).toEqual([...items[i].options].sort());
      expect(shuffled[i].options).toContain(items[i].correctAnswer);
      expect(shuffled[i].correctAnswer).toBe(items[i].correctAnswer);
    }
  });

  test('edge: flashcard items (no options) pass through unchanged', () => {
    const items = [{ frontText: 'F', backText: 'B' }];
    expect(shuffleQuizOptions(items)).toEqual(items);
  });

  test('edge: does not mutate the input items array', () => {
    const items = [{ questionText: 'Q', options: ['A', 'B', 'C', 'D'], correctAnswer: 'A' }];
    const original = JSON.parse(JSON.stringify(items));
    shuffleQuizOptions(items);
    expect(items).toEqual(original);
  });
});
