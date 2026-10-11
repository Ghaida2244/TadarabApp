import { describe, test, expect } from 'vitest';
import {
  parseDifficulty,
  validateCustomPrompt,
  computeMaxTokens,
  buildSourceText,
  buildPrompt,
  buildSystemPrompt,
  buildToolSchema,
  shuffleArray,
  shuffleQuizOptions,
  extractLocationTags,
  isLocationGrounded,
  filterGroundedItems,
  buildGroundingLogEntry,
  normalizeItems,
  normalizeCoveredTopics,
  normalizePreviousTopics,
  validatePreviousTopics,
  MAX_CUSTOM_PROMPT_LENGTH,
  MODEL_MAX_OUTPUT_TOKENS,
  MAX_COVERED_TOPICS,
  MAX_COVERED_TOPIC_LENGTH,
  MAX_PREVIOUS_TOPICS,
  MAX_PREVIOUS_TOPIC_LENGTH,
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
  test('normal: quiz always returns the flat model cap, regardless of count', () => {
    expect(computeMaxTokens('quiz', 10)).toBe(MODEL_MAX_OUTPUT_TOKENS);
  });

  test('normal: flashcard always returns the flat model cap, regardless of count', () => {
    expect(computeMaxTokens('flashcard', 10)).toBe(MODEL_MAX_OUTPUT_TOKENS);
  });

  test('edge: a large count still just returns the flat model cap, not an uncapped formula', () => {
    expect(computeMaxTokens('quiz', 1000)).toBe(MODEL_MAX_OUTPUT_TOKENS);
  });

  test('failure-adjacent: count=1 still returns the flat model cap, not a tiny budget', () => {
    expect(computeMaxTokens('quiz', 1)).toBe(MODEL_MAX_OUTPUT_TOKENS);
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
    expect(prompt).toContain('LEARNER INSTRUCTION HANDLING:');
    expect(prompt).toContain('SOURCE TAGS:');
    expect(prompt).toContain('SOURCE TEXT:');
    expect(prompt).toContain('[Material: Lecture 1]');
  });

  test('normal: the sourceLocation format rule lives in SOURCE TAGS, not DISTRIBUTION RULE', () => {
    const prompt = buildPrompt(baseArgs);
    const distributionIndex = prompt.indexOf('DISTRIBUTION RULE:');
    const sourceTagsIndex = prompt.indexOf('SOURCE TAGS:');
    const formatIndex = prompt.indexOf('sourceLocation format: <material title> | <tag text>');
    const distributionSection = prompt.slice(distributionIndex, sourceTagsIndex);
    expect(distributionSection).not.toContain('sourceLocation format: <material title> | <tag text>');
    expect(formatIndex).toBeGreaterThan(sourceTagsIndex);
  });

  test('normal: the language-of-the-source sentence appears exactly once', () => {
    const prompt = buildPrompt(baseArgs);
    const occurrences = prompt.split('same language as the source text').length - 1;
    expect(occurrences).toBe(1);
  });

  test('normal: quiz gets OPTIONS RULE and the full EXPLANATION RULE, not the flashcard sections', () => {
    const prompt = buildPrompt(baseArgs);
    expect(prompt).toContain('OPTIONS RULE (quiz only):');
    expect(prompt).toContain('EXPLANATION RULE:');
    expect(prompt).not.toContain('BACK TEXT SHAPE');
    expect(prompt).not.toContain('N/A for flashcards');
  });

  test('normal: flashcard gets BACK TEXT SHAPE and no EXPLANATION RULE section, not the quiz sections', () => {
    const prompt = buildPrompt({ ...baseArgs, type: 'flashcard' });
    expect(prompt).toContain('BACK TEXT SHAPE (flashcard only):');
    expect(prompt).not.toContain('EXPLANATION RULE');
    expect(prompt).not.toContain('OPTIONS RULE');
  });

  test('edge: multiple requested difficulty levels each get their own definition line', () => {
    const prompt = buildPrompt({ ...baseArgs, difficulties: ['easy', 'hard'] });
    expect(prompt).toContain('DIFFICULTY LEVELS REQUESTED: easy, hard');
    expect(prompt).toContain('easy: The learner recalls a fact');
    expect(prompt).toContain('hard: The learner must connect two or more ideas');
    expect(prompt).not.toContain('medium:');
  });

  test('edge: a present customPrompt is included verbatim', () => {
    const prompt = buildPrompt({ ...baseArgs, customPrompt: 'Make it exam-style.' });
    expect(prompt).toContain("LEARNER'S ADDITIONAL INSTRUCTION: Make it exam-style.");
  });

  test('normal: an absent customPrompt omits that section entirely', () => {
    const prompt = buildPrompt(baseArgs);
    expect(prompt).not.toContain("LEARNER'S ADDITIONAL INSTRUCTION");
  });

  test('normal: isRetake defaulting to false omits the RETAKE RULE section', () => {
    const prompt = buildPrompt(baseArgs);
    expect(prompt).not.toContain('RETAKE RULE');
  });

  test('edge: isRetake: true adds the RETAKE RULE section', () => {
    const prompt = buildPrompt({ ...baseArgs, isRetake: true });
    expect(prompt).toContain('RETAKE RULE (this is a retake of a previous attempt with the same settings):');
    expect(prompt).toContain('vary your phrasing');
  });

  test('normal: the NO MATERIAL-CITING rule is present for both quiz and flashcard, with the forbidden phrases, the example, and both exceptions', () => {
    for (const type of ['quiz', 'flashcard']) {
      const prompt = buildPrompt({ ...baseArgs, type });
      expect(prompt).toContain('NO MATERIAL-CITING RULE:');
      expect(prompt).toContain('"the lecture"');
      expect(prompt).toContain('"according to the lecture"');
      expect(prompt).toContain('"according to slide N"');
      expect(prompt).toContain('"the course material"');
      expect(prompt).toContain('"the document"');
      expect(prompt).toContain('"the text"');
      expect(prompt).toContain('المحاضرة');
      expect(prompt).toContain('حسب المحاضرة');
      expect(prompt).toContain('وفقًا للشريحة');
      expect(prompt).toContain('BPM focuses on improving end-to-end processes');
      expect(prompt).toContain('Applies only to the fields listed above, not to sourceLocation (see SOURCE TAGS) or "note".');
    }
  });

  test('normal: a previously-covered-topics bullet never appears when isRetake is false, even with a non-empty previousTopics', () => {
    const prompt = buildPrompt({ ...baseArgs, isRetake: false, previousTopics: ['BPM lifecycle', 'SLA'] });
    expect(prompt).not.toContain('RETAKE RULE');
    expect(prompt).not.toContain('Topics the learner already practised');
  });

  test('normal: isRetake true with an empty previousTopics shows the retake rule with no topics bullet', () => {
    const prompt = buildPrompt({ ...baseArgs, isRetake: true, previousTopics: [] });
    expect(prompt).toContain('RETAKE RULE (this is a retake of a previous attempt with the same settings):');
    expect(prompt).not.toContain('Topics the learner already practised');
  });

  test('normal: isRetake true with a non-empty previousTopics appends the topics bullet to the same RETAKE RULE section, listing every topic', () => {
    const prompt = buildPrompt({ ...baseArgs, isRetake: true, previousTopics: ['BPM lifecycle', 'SLA'] });
    expect(prompt).toContain('Topics the learner already practised: BPM lifecycle, SLA.');
    expect(prompt).toContain('Prefer ideas, terms and concepts from the material that are NOT in this');
    expect(prompt).toContain('Never produce fewer');
    expect(prompt).toContain('Do not mention this list');

    // Still one single section, not two — the topics bullet is part of the
    // same joined RETAKE RULE block, not a separate standalone section.
    const sections = prompt.split('\n\n');
    const retakeSection = sections.find((s) => s.startsWith('RETAKE RULE'));
    expect(retakeSection).toContain('Topics the learner already practised');
  });

  test('normal: sourceLocation format rule names the material title and tag, with the example, for both quiz and flashcard', () => {
    for (const type of ['quiz', 'flashcard']) {
      const prompt = buildPrompt({ ...baseArgs, type });
      expect(prompt).toContain('sourceLocation format: <material title> | <tag text>');
      expect(prompt).toContain('Always include it, even when only one material was provided.');
      expect(prompt).toContain('Lecture 1 - Introduction | Slide 5: Processes Everywhere');
      expect(prompt).toContain('separate them with "; "');
      expect(prompt).toContain('never invent a title');
    }
  });

  test('normal: the SOURCE TAGS multi-location example has no line break inside it', () => {
    const prompt = buildPrompt(baseArgs);
    expect(prompt).toContain(
      'Lecture 1 - Introduction | Slide 5: Processes Everywhere; Lecture 2 | Slide 3: Metrics\n',
    );
  });
});

describe('buildSystemPrompt', () => {
  test('normal: quiz gets the quiz-flavored tutor framing', () => {
    expect(buildSystemPrompt('quiz')).toContain('quiz them on what they\'ve learned');
  });

  test('normal: flashcard gets the flashcard-flavored tutor framing', () => {
    expect(buildSystemPrompt('flashcard')).toContain('create flashcards that reinforce');
  });

  test('edge: both share the same tutor/misconceptions framing', () => {
    for (const type of ['quiz', 'flashcard']) {
      const prompt = buildSystemPrompt(type);
      expect(prompt).toContain('knowledgeable tutor helping a learner study their course material');
      expect(prompt).toContain('common misconceptions');
    }
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

  test('edge: "coveredTopics" (an array of strings) is present but not required on both schemas', () => {
    for (const type of ['quiz', 'flashcard']) {
      const schema = buildToolSchema(type);
      const coveredTopics = schema.input_schema.properties.coveredTopics;
      expect(coveredTopics).toBeDefined();
      expect(coveredTopics.type).toBe('array');
      expect(coveredTopics.items).toEqual({ type: 'string' });
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

describe('extractLocationTags', () => {
  test('normal: pulls every bracketed tag, de-duplicated', () => {
    const text = '[Material: Lecture 1]\n[Slide 2]\nSome text.\n\n[Slide 5]\nMore text.\n[Slide 2]\nrepeat.';
    expect(extractLocationTags(text)).toEqual(['Material: Lecture 1', 'Slide 2', 'Slide 5']);
  });

  test('edge: no tags at all returns an empty list', () => {
    expect(extractLocationTags('plain text with no brackets')).toEqual([]);
  });

  test('failure-adjacent: an empty string returns an empty list, not an error', () => {
    expect(extractLocationTags('')).toEqual([]);
  });
});

describe('isLocationGrounded', () => {
  const tags = ['Material: Lecture 1', 'Slide 5'];

  test('normal: a readable rendering of a real tag matches (case-insensitive substring)', () => {
    expect(isLocationGrounded('Lecture 1, slide 5', tags)).toBe(true);
  });

  test('edge: a tag with no surrounding prose still matches', () => {
    expect(isLocationGrounded('Slide 5', tags)).toBe(true);
  });

  test('failure: a location naming a slide that was never tagged is not grounded', () => {
    expect(isLocationGrounded('Slide 99', tags)).toBe(false);
  });

  test('failure: missing/empty sourceLocation is not grounded', () => {
    expect(isLocationGrounded(undefined, tags)).toBe(false);
    expect(isLocationGrounded('', tags)).toBe(false);
  });

  test('normal: the "Material Title | Tag" prefix format (Part C) still grounds correctly — the tag itself is still a real substring', () => {
    const realTags = extractLocationTags('[Material: Lecture 1 - Introduction]\n[Slide 5: Processes Everywhere]\nSome text.');
    expect(isLocationGrounded('Lecture 1 - Introduction | Slide 5: Processes Everywhere', realTags)).toBe(true);
    // Multi-location, "; "-separated, with a repeated material title per Part C.
    expect(
      isLocationGrounded('Lecture 1 - Introduction | Slide 5: Processes Everywhere; Lecture 2 | Slide 3: Metrics', realTags),
    ).toBe(true);
  });
});

describe('normalizeItems', () => {
  test('normal: an array passes through unchanged', () => {
    const items = [{ questionText: 'Q1' }];
    expect(normalizeItems(items)).toBe(items);
  });

  test('normal: a valid JSON-string array is parsed', () => {
    const items = [{ questionText: 'Q1' }, { questionText: 'Q2' }];
    expect(normalizeItems(JSON.stringify(items))).toEqual(items);
  });

  test('failure: an invalid JSON string returns null', () => {
    expect(normalizeItems('not valid json')).toBeNull();
  });

  test('failure: a non-array value (including a JSON-string object) returns null', () => {
    expect(normalizeItems(42)).toBeNull();
    expect(normalizeItems(null)).toBeNull();
    expect(normalizeItems(undefined)).toBeNull();
    expect(normalizeItems(JSON.stringify({ questionText: 'Q1' }))).toBeNull();
  });
});

describe('filterGroundedItems', () => {
  const sourceText = '[Material: Lecture 1]\n[Slide 5]\nPhotosynthesis is...';

  test('normal: a grounded item is kept, an ungrounded one is discarded', () => {
    const items = [
      { questionText: 'Q1', sourceLocation: 'Lecture 1, Slide 5' },
      { questionText: 'Q2', sourceLocation: 'Slide 42 (made up)' },
    ];
    const { grounded, discarded } = filterGroundedItems(items, sourceText);
    expect(grounded).toEqual([items[0]]);
    expect(discarded).toEqual([items[1]]);
  });

  test('edge: every item grounded yields an empty discarded list', () => {
    const items = [{ questionText: 'Q1', sourceLocation: 'Slide 5' }];
    const { grounded, discarded } = filterGroundedItems(items, sourceText);
    expect(grounded).toEqual(items);
    expect(discarded).toEqual([]);
  });

  test('failure: an empty items array returns two empty lists, not an error', () => {
    const { grounded, discarded } = filterGroundedItems([], sourceText);
    expect(grounded).toEqual([]);
    expect(discarded).toEqual([]);
  });
});

describe('buildGroundingLogEntry', () => {
  test('normal: reports the ungrounded count, the total count, and each sourceLocation', () => {
    const discarded = [
      { questionText: 'Q1', sourceLocation: 'Slide 42' },
      { questionText: 'Q2', sourceLocation: 'Slide 99' },
    ];
    const entry = buildGroundingLogEntry(discarded, 5);
    expect(entry).toEqual({
      event: 'ungrounded_source_locations',
      ungroundedCount: 2,
      totalCount: 5,
      sourceLocations: ['Slide 42', 'Slide 99'],
    });
  });

  test('normal: never includes question/answer text or anything beyond sourceLocation', () => {
    const discarded = [{ questionText: 'Q1', explanation: 'Because...', sourceLocation: 'Slide 1' }];
    const entry = buildGroundingLogEntry(discarded, 1);
    expect(JSON.stringify(entry)).not.toContain('Q1');
    expect(JSON.stringify(entry)).not.toContain('Because...');
  });

  test('edge: only the first 10 sourceLocations are included', () => {
    const discarded = Array.from({ length: 15 }, (_, i) => ({ sourceLocation: `Slide ${i}` }));
    const entry = buildGroundingLogEntry(discarded, 20);
    expect(entry.ungroundedCount).toBe(15);
    expect(entry.sourceLocations).toHaveLength(10);
    expect(entry.sourceLocations[0]).toBe('Slide 0');
    expect(entry.sourceLocations[9]).toBe('Slide 9');
  });

  test('edge: a sourceLocation longer than 120 characters is truncated', () => {
    const longLocation = 'x'.repeat(200);
    const discarded = [{ sourceLocation: longLocation }];
    const entry = buildGroundingLogEntry(discarded, 1);
    expect(entry.sourceLocations[0]).toHaveLength(120);
  });

  test('failure-adjacent: a missing sourceLocation becomes an empty string, not an error', () => {
    const discarded = [{ questionText: 'Q1' }];
    const entry = buildGroundingLogEntry(discarded, 1);
    expect(entry.sourceLocations).toEqual(['']);
  });
});

describe('normalizeCoveredTopics', () => {
  test('normal: trims whitespace from each entry', () => {
    expect(normalizeCoveredTopics(['  BPM lifecycle  ', ' SLA '])).toEqual(['BPM lifecycle', 'SLA']);
  });

  test('normal: drops empty and non-string entries', () => {
    expect(normalizeCoveredTopics(['BPM', '', '   ', 42, null, undefined, {}])).toEqual(['BPM']);
  });

  test('normal: removes case-insensitive duplicates, keeping the first casing', () => {
    expect(normalizeCoveredTopics(['BPM lifecycle', 'bpm lifecycle', 'BPM LIFECYCLE'])).toEqual(['BPM lifecycle']);
  });

  test('edge: truncates each entry to 60 characters', () => {
    const long = 'x'.repeat(100);
    expect(normalizeCoveredTopics([long])[0]).toHaveLength(MAX_COVERED_TOPIC_LENGTH);
  });

  test('edge: caps the list at 30 entries', () => {
    const topics = Array.from({ length: 40 }, (_, i) => `Topic ${i}`);
    expect(normalizeCoveredTopics(topics)).toHaveLength(MAX_COVERED_TOPICS);
  });

  test('failure-adjacent: a missing/non-array field returns an empty array, not an error', () => {
    expect(normalizeCoveredTopics(undefined)).toEqual([]);
    expect(normalizeCoveredTopics(null)).toEqual([]);
    expect(normalizeCoveredTopics('not an array')).toEqual([]);
  });
});

describe('normalizePreviousTopics', () => {
  test('normal: trims, dedupes case-insensitively, and drops non-string entries', () => {
    expect(normalizePreviousTopics([' Process modeling ', 'process modeling', 7])).toEqual(['Process modeling']);
  });

  test('edge: truncates each entry to 80 characters', () => {
    const long = 'x'.repeat(200);
    expect(normalizePreviousTopics([long])[0]).toHaveLength(MAX_PREVIOUS_TOPIC_LENGTH);
  });

  test('edge: caps the list at 100 entries', () => {
    const topics = Array.from({ length: 150 }, (_, i) => `Topic ${i}`);
    expect(normalizePreviousTopics(topics)).toHaveLength(MAX_PREVIOUS_TOPICS);
  });

  test('failure-adjacent: a missing/non-array field returns an empty array, not an error', () => {
    expect(normalizePreviousTopics(undefined)).toEqual([]);
    expect(normalizePreviousTopics(null)).toEqual([]);
  });
});

describe('validatePreviousTopics', () => {
  test('normal: absent/null passes (previousTopics is optional)', () => {
    expect(() => validatePreviousTopics(undefined)).not.toThrow();
    expect(() => validatePreviousTopics(null)).not.toThrow();
  });

  test('normal: an array of strings passes, including an empty array', () => {
    expect(() => validatePreviousTopics(['BPM lifecycle'])).not.toThrow();
    expect(() => validatePreviousTopics([])).not.toThrow();
  });

  test('failure: a non-array value is rejected', () => {
    expect(() => validatePreviousTopics('BPM lifecycle')).toThrow(/must be an array/);
    expect(() => validatePreviousTopics(42)).toThrow(/must be an array/);
    expect(() => validatePreviousTopics({})).toThrow(/must be an array/);
  });

  test('failure-adjacent: non-string entries inside the array do not throw — sanitized, not rejected', () => {
    expect(() => validatePreviousTopics(['BPM', 42, null])).not.toThrow();
  });
});
