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
  }`), `difficulty` (a single level or a list of them), and an optional
  `customPrompt` (server-side capped at 300 characters — a backup to the
  Flutter-side `maxLength`, since a client-only check is bypassable) are all
  validated before anything is sent to Claude. Anything invalid →
  `400 Bad Request` with a specific message, never a silent failure.
- **The prompt logic.** `src/generation.js` builds the exact prompt text
  Claude receives — content, wording, difficulty distribution, the
  options-vs-front/back-text shape per `type`, explanation and
  source-location rules, multi-material handling, and how an optional
  student `customPrompt` gets folded in — all per
  `quiz_flashcard_generation_spec.md` at the project root, which is the
  actual source of truth (this README only summarizes it).
- **Structured output, not parsed text.** Claude is called with **Tool
  Use** and a strict per-type JSON schema (quiz items require exactly 4
  `options` + `correctAnswer` + `explanation` + `sourceLocation` +
  `difficulty`; flashcard items require `frontText`/`backText` instead —
  no `options`/`correctAnswer` at all), so the response is guaranteed
  well-formed instead of relying on Claude to return valid JSON as plain
  text.
- **Model + token budget.** Pinned to `claude-haiku-4-5-20251001` (not the
  default/latest, so behavior can't shift under us on a model update).
  `max_tokens` is computed per request (`500 + count×350` for quiz,
  `500 + count×200` for flashcard) and capped at that model's real max
  output (64,000).
- **Server-side shuffle.** For quizzes, `src/generation.js` shuffles each
  question's option order itself (Fisher–Yates) after Claude responds —
  Claude is never asked to randomize its own output, which it can't be
  trusted to do well.
- **Response shape.** On success:
  `{ "uid": "...", "type": "quiz", "items": [...], "note": null }`. `note`
  is only ever a non-null string when Claude generated fewer items than
  requested (or none) and explains why — the app should show that directly
  to the student rather than a generic error, per the "never pad with
  low-quality items" rule in CLAUDE.md.
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
  building, the Tool Use schemas, `customPrompt`/`difficulty` validation,
  the `max_tokens` formula, and option shuffling. Pure functions in and out
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
  "materials": [{ "title": "Lecture 1", "sourceText": "[Slide 1]\n..." }]
}
```

`type` is `"quiz"` or `"flashcard"`. `difficulty` accepts a single level or a
list (`["easy","hard"]`).

## Tests

```
cd worker
npm install
npm test
```

Covers the pure logic in `src/generation.js` (prompt building, the Tool Use
schemas, `customPrompt`/`difficulty` validation, the dynamic `max_tokens`
formula and its cap, and option shuffling) — not the HTTP handler itself,
which has no real caller yet (Phase C's Quiz/Flashcard generation UI isn't
built).
