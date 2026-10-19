# Tadarab AI Worker

A **Cloudflare Worker** — a small serverless HTTP service — that sits between
the Flutter app and the Claude API. The app never holds the Anthropic key: it
calls this Worker with the student's Firebase ID token, the Worker verifies
that token against Google's public keys, then calls Claude itself using the
key stored as a Worker secret (never committed, never sent to the client).

## What's built here

**One route: `POST /generate`.** It's the only thing this Worker does —
turn a student's chosen materials + settings into AI-generated quiz
questions or flashcards.

- **Identity verification.** Every request must carry
  `Authorization: Bearer <firebase-id-token>`. The Worker verifies that
  token's signature against Firebase/Google's published JWKS (fetched and
  cached by the `jose` library) and checks its issuer/audience against this
  project's Firebase project ID. Missing header, expired token, wrong
  project, anything that fails verification → `401 Unauthorized`. No
  Firestore/Firebase Admin round trip is needed for this — the token itself
  proves identity.
- **Request validation.** `type` (`"quiz"` or `"flashcard"`), `count`
  (positive integer), `materials` (non-empty array of `{ title, sourceText
  }`), `difficulty` (a single level or a list of them), an optional
  `customPrompt` (server-side capped at 300 characters — a backup to the
  Flutter-side `maxLength`, since a client-only check is bypassable), and
  an optional `isRetake`/`previousTopics` pair (see **Retakes** below) are
  all validated before anything is sent to Claude. Anything invalid →
  `400 Bad Request` with a specific message, never a silent failure.
- **The prompt logic.** `src/generation.js`'s `buildPrompt` builds the exact
  prompt text Claude receives — content, wording/language, the
  no-material-citing rule, difficulty distribution (across levels and, for
  multi-material requests, across materials too), the
  options-vs-back-text shape per `type`, the explanation rule (quiz only),
  distinctness, how the retake rule and an optional student `customPrompt`
  get folded in, and the source-tag/`sourceLocation` rules — all per
  `quiz_flashcard_generation_spec.md` at the project root, which stays the
  readable paraphrase of this file's actual, current prompt text (this
  README only summarizes it further).
- **Structured output, not parsed text.** Claude is called with **Tool
  Use** and a strict per-type JSON schema (quiz items require exactly 4
  `options` + `correctAnswer` + `explanation` + `sourceLocation` +
  `difficulty`; flashcard items require `frontText`/`backText` instead —
  no `options`/`correctAnswer` at all), plus an optional response-level
  `note` and `coveredTopics` (see **Response shape** below), so the
  response is guaranteed well-formed instead of relying on Claude to
  return valid JSON as plain text.
- **Model + token budget.** Pinned to `claude-haiku-4-5-20251001` (not the
  default/latest, so behavior can't shift under us on a model update).
  `max_tokens` is a flat cap at that model's real max output (64,000) on
  every request, regardless of `type`/`count` — there's no retry-on-
  `max_tokens` logic anywhere else, so the Worker always grants Claude the
  full available budget rather than a per-item estimate that could fall
  short (see `computeMaxTokens` in `src/generation.js`).
- **Server-side shuffle.** For quizzes, `src/generation.js` shuffles each
  question's option order itself (Fisher–Yates) after Claude responds —
  Claude is never asked to randomize its own output, which it can't be
  trusted to do well.
- **Retakes.** The app sends `isRetake: true` plus `previousTopics` (an
  array of short topic strings) when the student retakes a session. This
  is **soft guidance only, sent fresh per request and never stored by the
  Worker**: the prompt asks Claude to prefer ideas/terms/concepts not in
  `previousTopics`, and if nothing new is left, to cover them from a
  different angle (a different aspect, example, or way of asking) rather
  than ever producing fewer items. `previousTopics` is built by the app
  from the *retaken session's own* stored `coveredTopics` only — never a
  union across its whole retake chain — and is capped/sanitized again
  server-side (`normalizePreviousTopics`) regardless of what the app sent.
- **Response shape.** On success:
  `{ "uid": "...", "type": "quiz", "items": [...], "note": null,
  "coveredTopics": [...] }`. `note` is only ever a non-null string when
  Claude generated fewer items than requested (or none) and explains why —
  the app should show that directly to the student rather than a generic
  error, per the "never pad with low-quality items" rule in CLAUDE.md.
  `coveredTopics` is Claude's own short list of the concepts/terms the
  generated items cover (sanitized/capped via `normalizeCoveredTopics`) —
  the app stores it on the session and later feeds it back as that
  session's own retake's `previousTopics`.
- **Grounding check (monitoring only).** Before responding, the Worker
  checks each item's `sourceLocation` against the real bracketed tags
  extracted from the request's own source text
  (`extractLocationTags`/`filterGroundedItems`). An ungrounded item is
  **never dropped or regenerated** — it's logged (`console.log`, a count
  plus each ungrounded item's truncated `sourceLocation`, no question/
  answer/source text) so the prompt can keep being tuned, per CLAUDE.md's
  grounding rule: a slightly imprecise `sourceLocation` shown to the
  student is acceptable, losing a valid item is not.
- **Status: deployed and live** at
  `https://tadarab-ai-worker.tadarab.workers.dev`. Verified against the real
  deployment with a throwaway Firebase test account: no `Authorization`
  header → 401, unknown route → 404, a valid token with an invalid body →
  400 with the real validation message (confirming the deployed code is
  this implementation, not a stale build). A real end-to-end call through
  to Claude has also been run once (small, deliberately cost-controlled)
  and its raw response checked against the schema/rules above by hand.

**Not built here:** extracting `sourceText` out of an uploaded PPTX/DOCX/TXT
file — that's the Courses/Material-upload feature's job; this Worker only
ever receives text that's already been extracted, in the request body.

## Files

- `src/index.js` — the thin HTTP handler: routes `POST /generate`, verifies
  the Firebase token, validates the request body, calls the Claude API, and
  maps everything to a JSON response. No business logic of its own.
- `src/generation.js` — the actual, pure, unit-tested logic: prompt
  building, the Tool Use schemas, `customPrompt`/`difficulty`/
  `previousTopics` validation and normalization, the `max_tokens` cap,
  option shuffling, and the grounding check. Pure functions in and out
  (no `fetch`, no `env`), which is what makes it testable without mocking
  the network.
- `test/generation.test.js` — unit tests for everything in `generation.js`.
- `wrangler.toml` — Worker config (name, compatibility date, routes).

## One-time setup (once the Anthropic API key is available)

```
cd worker
npm install
npx wrangler login
npx wrangler secret put ANTHROPIC_API_KEY
npx wrangler deploy
```

`wrangler login` opens a browser for Cloudflare auth — a human has to do
that step. `wrangler secret put` prompts for the key value and stores it
server-side; it is never written to a file in this repo.

## Local dev

```
cd worker
npm install
npx wrangler dev
```

For local dev, put the key in `worker/.dev.vars` (already gitignored):

```
ANTHROPIC_API_KEY=sk-ant-...
```

## Endpoint reference

`POST /generate` — `Authorization: Bearer <firebase-id-token>` header
required. Body:

```json
{
  "type": "quiz",
  "count": 10,
  "difficulty": "easy",
  "customPrompt": "optional, ≤300 characters",
  "materials": [{ "title": "Lecture 1", "sourceText": "[Slide 1]\n..." }],
  "isRetake": false,
  "previousTopics": ["BPM lifecycle", "SLA"]
}
```

`type` is `"quiz"` or `"flashcard"`. `difficulty` accepts a single level or a
list (`["easy","hard"]`). Each entry in `materials` needs a non-empty
`title` and `sourceText` — the source text is expected to already carry the
upload-time location tags (`[Slide N: Title]`, `[Heading N: Text]`,
`[Paragraph N]`); the Worker itself wraps each material in its own
`[Material: Title]` header before sending it to Claude. `isRetake` and
`previousTopics` are both optional and default to `false`/`[]` — see
**Retakes** above.

Response on success:

```json
{
  "uid": "<the caller's Firebase uid>",
  "type": "quiz",
  "items": [
    {
      "questionText": "...",
      "options": ["...", "...", "...", "..."],
      "correctAnswer": "...",
      "explanation": "...",
      "sourceLocation": "Lecture 1 - Introduction | Slide 5: Processes Everywhere",
      "difficulty": "medium"
    }
  ],
  "note": null,
  "coveredTopics": ["Process lifecycle", "..."]
}
```

A flashcard item has `frontText`/`backText` instead of `options`/
`correctAnswer`/`explanation`. `sourceLocation` is always `<material title>
| <tag text>`; an item that draws on more than one location joins them with
`"; "` (see `quiz_flashcard_generation_spec.md`'s SOURCE TAGS rule for the
exact format and an example).

## Tests

```
cd worker
npm install
npm test
```

Covers the pure logic in `src/generation.js` (prompt building for both
types and for a retake, the Tool Use schemas, `customPrompt`/`difficulty`/
`previousTopics` validation and normalization, the `max_tokens` cap,
option shuffling, and the grounding check) — not `src/index.js`'s HTTP
handler itself, which has no automated test coverage here (it was verified
once by hand against the live deployment — see **Status** above). The app
now has real callers for `POST /generate` on both sides —
`QuizGenerationClient` (Quiz) and `FlashcardService.generateFlashcards`
(Flashcards) each make the real HTTP call.
