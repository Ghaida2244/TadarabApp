# CLAUDE.md — Tadarab Project Memory (Team Rebuild)

This file is read automatically by Claude Code at the start of every session
in this folder. It does not need to be pasted in manually.

---

## Who's building this and how

This is a **team rebuild** of an app called Tadarab, built by **4 students**
working together. This is *not* a solo learning project — don't default to
explaining every Flutter/Dart concept from scratch unless asked. Do keep
comments in the code (see "Code style" below), since this is also feeding
into a course SRS/documentation deliverable.

**Team members** *(see "Feature split" below for who owns which vertical):*
- Manar
- Ghaida
- Deemah
- Leen

**Work is done in three phases, in this order:**
1. **Phase A — Shared backend.** Firebase (Auth + Firestore + Storage +
   security rules) and the shared data models. Built together, one shared
   branch, not split.
2. **Phase B — Shared UI.** Design system (theme, shared widgets) and the
   core screens every feature depends on (auth screens, navigation shell,
   home skeleton). Built together, so the look is consistent before anyone
   branches off.
3. **Phase C — Split by feature.** Each member takes one feature vertical
   (data + logic + UI for that feature) on her own branch. See "Feature
   split" and "Git workflow" below.

**Do not start Phase C work (or create feature branches) until Phase A and
Phase B are both merged to `main` and confirmed working by the team.**

---

## Step 0 — Before writing any file, confirm these are done

Claude Code: **do not run `flutter create`, `flutterfire configure`, or any
Firebase/Cloudflare command until the user confirms every item below.** Ask
for confirmation explicitly if any are missing — these all require a human
to click through a web console or CLI login prompt; you cannot do them.

- [ ] Firebase project created (console.firebase.google.com), named for this
      project
- [ ] Blaze (pay-as-you-go) plan enabled on that project — required for
      Storage; Storage will silently fail to enable on the free Spark plan
- [ ] Authentication → Email/Password provider enabled in that project
- [ ] Firestore Database created (production mode, not test mode)
- [ ] Firebase Storage enabled
- [ ] `firebase login` already run successfully on this machine (Firebase CLI
      installed: `npm install -g firebase-tools`)
- [ ] FlutterFire CLI installed (`dart pub global activate flutterfire_cli`)
- [ ] GitHub repo created, empty, all 4 members added as collaborators
- [ ] Branch protection on `main` enabled (require PR + 1 approval, no direct
      push)
- [ ] Cloudflare account created (free tier is fine)
- [ ] Anthropic API key obtained from console.anthropic.com (do **not** paste
      the raw key value into chat with Claude Code — it goes straight into
      `wrangler secret put` at deploy time, never into a committed file)
- [ ] `docs/` folder ready with the original SRS, `Attributes Dictionary
      Table.png`, `Class Diagram.png`, and screen mockups copied in — these
      remain the source of truth for entity fields and screen layout

## What Claude Code can and can't do here

- **Can:** run `flutter`, `dart`, `git`, `firebase`, `flutterfire`, `wrangler`
  CLI commands; write and edit all project files; write and deploy Firestore
  rules, Storage rules, and the Cloudflare Worker code; run tests; commit and
  push to feature branches.
- **Can't:** create the Firebase project, enable Blaze, click "enable" on
  Auth/Firestore/Storage in a console, create the GitHub repo, create a
  Cloudflare account, or generate/retrieve API keys. If a command fails
  because one of these wasn't done, stop and tell the user exactly which
  Step 0 item is missing — don't try to work around it.

---

## Project: Tadarab

An AI-powered study app. Students upload lecture materials, and the app
generates multiple-choice quizzes and flashcards from that content, with
explanations, source-linking back to the material, and progress tracking.

- **Target users:** students aged 16+, English-language content
- **Platform:** Android only, built with Flutter
- **Supported upload formats:** PPTX, DOCX, TXT

### Core features (functional requirements)

1. **Account management** — sign up, log in, log out, password reset, edit profile
2. **Course management** — add/view/delete courses (materials organized under courses)
3. **Material upload** — upload PPTX/DOCX/TXT files tied to a course
4. **Quiz & flashcard generation** — user selects material(s), difficulty,
   mode, count of questions/cards, and an optional custom prompt; AI
   generates the set
5. **Session management** — view past results, retake (new questions/cards,
   same settings — latest retake becomes "current"), resume unfinished,
   delete a session
6. **Quiz modes:** Exam mode (answer all, then submit) / Learning mode
   (immediate feedback per question — correctness, explanation, source
   location)
7. **Flashcards** — flip to reveal answer, mark "I Know It" / "Needs Review"
8. **Review & practice** — review wrong answers after an exam; practice wrong
   answers after learning mode; review "Needs Review" flashcards
9. **Daily study progress** — track/display progress from completed sessions
10. **Calendar** — add/view/delete events (name, color, date, time, optional
    linked course, optional reminder); notification when reminder is due
11. **Points & ranks** — points from sessions; 10 ranks from Beginner Learner
    (0–99) to Master Learner (7000+); view rank + thresholds; optional daily
    study reminder notification

### Data model — 9 entities

`docs/Attributes Dictionary Table.png` and `docs/Class Diagram.png` are the
source of truth for exact fields — check them before finalizing any model
class, not just this summary.

- **Student:** email, name, ~~password~~ (never stored — Firebase Auth owns
  this), totalPoints, currentRank, reminderTime, reminderEnabled
- **Course:** courseID, courseName, color, email (owner)
- **StudyMaterial:** materialID, title, type, document, courseID
- **Session** (shared fields, merged directly into QuizSession/FlashcardSession
  — see Firestore schema below, not a separate collection): sessionID,
  createdAt, completedAt, earnedPoints, isSessionCompleted, difficultyLevel,
  customPrompt, email, courseID
- **SessionMaterial:** modeled as a list of material IDs on the session
  document, not a separate collection (Firestore doc model, not relational)
- **QuizSession** (extends Session): numberOfQuestions, mode
  (Learning/Exam), correctAnswers, incorrectAnswers, currentQuestionIndex
- **Question:** questionID, questionText, correctAnswer, explanation,
  sourceLocation, studentAnswer, options (list), sessionID
- **FlashcardSession** (extends Session): numberOfFlashcards,
  currentFlashcardIndex, needsReviewCount, knownCount
- **Flashcard:** flashcardID, frontText, backText, reviewStatus (Know
  It/Needs Review), sourceLocation, sessionID
- **CalendarEvent:** eventID, eventName, eventDate, eventTime,
  reminderEnabled, reminderBefore, reminderUnit (Minutes/Hours/Days/Weeks),
  color, email, courseID (nullable)

**Model accuracy audit — required whenever a model class is created or
changed.** Compare every field against `docs/Attributes Dictionary
Table.png` field-by-field and report: fields that match, fields missing,
fields added that aren't in the table (with reason). Report this comparison
*before* fixing mismatches — don't silently correct them.

**Grounding requirement for generated content** — every question/flashcard
must cite the exact excerpt/location it came from; after generation, verify
the cited excerpt actually appears in the material's extracted text before
showing it, discard/regenerate if not; include a "Report this question"
option in the UI as a fallback; if the material can't support the requested
count, generate as many good ones as it supports and tell the student —
never pad with low-quality or off-topic items.

### Non-functional requirements

- Material upload completes within 5 seconds for files up to 10MB
- AI-generated content appears within 10 seconds of the request
- Clean, intuitive UI usable without training
- No crashes during normal use; recover within 1 minute of unexpected failure
- Every network/API call (Auth, Firestore, Storage, Claude) must catch
  failures and show a clear, actionable message with a retry option — never
  a frozen screen or silent failure

---

## Firestore schema

Subcollections under the owning user, not top-level collections — keeps
security rules simple and scoped by construction:

```
users/{uid}                                          → Student
users/{uid}/courses/{courseId}                       → Course
users/{uid}/courses/{courseId}/materials/{materialId} → StudyMaterial
users/{uid}/quizSessions/{sessionId}                 → QuizSession
users/{uid}/quizSessions/{sessionId}/questions/{questionId} → Question
users/{uid}/flashcardSessions/{sessionId}            → FlashcardSession
users/{uid}/flashcardSessions/{sessionId}/flashcards/{flashcardId} → Flashcard
users/{uid}/events/{eventId}                         → CalendarEvent
```

Use the Firebase Auth UID as the Student document ID (not email — emails
can change, UIDs don't). Keep `email` as a field too since other entities
reference it.

## Security rules (Phase A, before any real data exists)

Every collection above is owner-scoped: `request.auth.uid == uid` for every
read and write, no exceptions, no public collections. After writing rules
for a phase, verify with two real test accounts that account A genuinely
cannot read or write account B's data — report what was tested and the
result, don't just say the rules "should" work.

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{uid} {
      allow read, write: if request.auth != null && request.auth.uid == uid;

      match /courses/{courseId} {
        allow read, write: if request.auth != null && request.auth.uid == uid;
        match /materials/{materialId} {
          allow read, write: if request.auth != null && request.auth.uid == uid;
        }
      }
      match /quizSessions/{sessionId} {
        allow read, write: if request.auth != null && request.auth.uid == uid;
        match /questions/{questionId} {
          allow read, write: if request.auth != null && request.auth.uid == uid;
        }
      }
      match /flashcardSessions/{sessionId} {
        allow read, write: if request.auth != null && request.auth.uid == uid;
        match /flashcards/{flashcardId} {
          allow read, write: if request.auth != null && request.auth.uid == uid;
        }
      }
      match /events/{eventId} {
        allow read, write: if request.auth != null && request.auth.uid == uid;
      }
    }
  }
}
```

## Storage (Firebase Storage — Blaze plan)

Files live under `users/{uid}/...`. Rules mirror the Firestore ownership
check, plus enforce the 10MB limit server-side (not just client-side):

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /users/{uid}/{allPaths=**} {
      allow read, write: if request.auth != null && request.auth.uid == uid
                          && request.resource.size < 10 * 1024 * 1024;
    }
  }
}
```

Before a file is accepted client-side: check actual file content/type (not
just extension — a renamed `.docx` that isn't a real DOCX must be rejected),
enforce the 10MB limit before upload starts, and reject corrupted/unreadable
files with a clear message rather than passing them to generation.

## AI generation — Cloudflare Worker + Claude API

The Flutter app never holds the Claude API key. It calls a Cloudflare
Worker, which verifies the caller's Firebase ID token, then calls Claude
using the key stored as a Worker secret (`wrangler secret put`). Set this up
once during Phase A; every generation call in the app goes through it.

---

## Code style

- Every class and public function gets a short doc comment explaining what
  it does and why it exists.
- Every field on a model class gets its own one-line comment explaining what
  it represents.
- Use the shared `AppTheme` (colors, typography, buttons, cards) on every
  screen from Phase B onward — no plain default Flutter styling.
- Before starting a new phase or feature, present a short plan (what it
  covers, what it'll look/behave like, open questions) and wait for
  confirmation before writing code.
- Update the Progress Log below at the end of every phase/feature, before
  starting the next.
- Commit with a clear message naming the phase/feature (e.g. "Phase A:
  Firebase backend + security rules", "Feature: Calendar & reminders").

## Testing requirements

- Any logic that isn't purely UI (validators, points calculations, the
  cooldown timer, checking the validity of AI-generated content) needs a
  unit test covering the normal case, an edge case, and at least one failure
  case.
- Any screen with distinct states (loading/empty/error/success, form
  validation) needs at least one widget test per state shown in the design,
  not just the primary state.
- Security rules keep using the existing two-real-account verification
  method — that's not a substitute for unit/widget tests.
- Run `flutter test` before considering any feature or phase done, and
  report the actual pass/fail counts in detail, not just "tests pass."
- Tests live in `test/`, mirroring the `lib/` folder structure.

## Git workflow (Phase C onward)

- `main` is protected: no direct pushes, PR + 1 teammate approval required.
- One branch per feature, named `feature/<short-name>` (e.g.
  `feature/courses`, `feature/quiz-sessions`, `feature/flashcards`,
  `feature/calendar-points`).
- Shared files (models, `AppTheme`, routing, `main.dart`) are frozen after
  Phase B merges — a change to any of them during Phase C needs a PR
  reviewed by everyone, not just the branch owner, since all four depend on
  them.
- Pull, don't assume: rebase/merge `main` into your feature branch regularly
  so your PR doesn't arrive with a huge, stale diff.

## Feature split

| Member | Feature | Branch |
|---|---|---|
| Manar | Courses & Material upload | `feature/courses` |
| Ghaida | Quiz generation & Sessions | `feature/quiz-sessions` |
| Deemah | Flashcards & Sessions | `feature/flashcards` |
| Leen | Calendar & Points/Ranks & Profile | `feature/calendar-points` |

---

## Progress Log

*(Claude Code: update this section at the end of every phase/feature —
mark it done, note decisions made, note what starts next.)*

- **Phase A — Shared backend:** done (branch `phase-a-shared-backend`, PR
  pending). Firebase project `tadarabapp-2e060` confirmed configured (Blaze,
  Auth email/password, Firestore, Storage all enabled in console); the
  second project in the account (`tadarab-db706` / "Tadarab") is an
  unrelated leftover and is not used. Added `firebase_core`, `firebase_auth`,
  `cloud_firestore`, `firebase_storage`; wired `Firebase.initializeApp()` in
  `main.dart` with a loading/retry screen (shows "Tadarab — Phase A backend
  ready" once connected). Wrote all 9 Dart model classes in `lib/models/`
  against `docs/Attributes Dictionary Table.png` and `docs/Class
  Diagram.png`. Deviations from the Attributes Dictionary Table, confirmed
  with the team: `Student.password` omitted (Firebase Auth owns
  credentials); `StudyMaterial.document` stores a Storage path/URL, not a
  BLOB; `Session.isTemporary` (Class Diagram only) left out;
  `Question.isCorrect` (Class Diagram only) is a computed getter
  (`studentAnswer == correctAnswer`), not a stored field, to avoid a
  duplicated value that could drift out of sync. Deployed `firestore.rules`
  and `storage.rules` (owner-scoped, matching the rules in this file) and
  verified both with real two-account tests (Firestore: 9/9 checks passed;
  Storage: 6/6 checks passed after fixing a real bug — the original
  `allow read, write` rule combined with `request.resource.size` silently
  denied all reads, since `request.resource` only exists on writes; split
  into separate `allow read` / `allow write` rules). Scaffolded the
  Cloudflare Worker in `worker/` (Firebase ID token verification via Google's
  JWKS + Claude proxy at `POST /generate`); `wrangler deploy --dry-run`
  compiles cleanly. See `worker/README.md`.

  **Deployed.** `ANTHROPIC_API_KEY` set via `wrangler secret put`; live at
  `https://tadarab-ai-worker.tadarab.workers.dev`. Verified against the live
  deployment with a real test account (created and deleted via the Identity
  Toolkit REST API, same method as the Firestore/Storage rules
  verification): no `Authorization` header → 401; unknown route → 404; a
  valid token with a body missing `"type"` → 400 with the *new* validation
  message (`"type" must be one of quiz, flashcard`), not the old Phase-A
  stub's "missing prompt" — confirming the deployed code is the real
  `quiz_flashcard_generation_spec.md` implementation, not a stale build.
  Did not send an actual generation request through to Claude (would spend
  real API credits without being asked) — that's still unverified against
  the live model and has no real caller yet (Phase C).

  **`POST /generate` implemented for real**, per `quiz_flashcard_generation_spec.md`
  at the project root (that file is the source of truth — this is a summary,
  not a replacement). `worker/src/generation.js` holds the pure logic
  (`worker/src/index.js` is just the HTTP handler around it): builds the
  exact prompt template from the spec (content/wording/difficulty/
  distribution/options-or-backtext/explanation/multi-material/student-
  instruction rules, substituted per request); forces structured output via
  Tool Use with a strict schema (quiz: `questionText`/`options`(exactly 4)/
  `correctAnswer`/`explanation`/`sourceLocation`/`difficulty`; flashcard:
  `frontText`/`backText`/`sourceLocation`/`difficulty` — no options/
  correctAnswer at all) — never a plain-text "return JSON" instruction;
  model is pinned to `claude-haiku-4-5-20251001`, not the default/latest;
  `max_tokens` is dynamic (`500 + count×350` quiz / `500 + count×200`
  flashcard) capped at that model's actual max output (64,000 — confirmed
  against Anthropic's docs at implementation time, not assumed); quiz
  option order is shuffled (Fisher-Yates) in Worker code after Claude
  responds, never left to Claude to randomize itself; `customPrompt` is
  capped at 300 characters server-side as a backup to the (separate)
  Flutter-side `maxLength`, since a client-only check is bypassable.
  `difficulty` accepts a single level or a list. The upload-time
  empty/corrupted-file rejection the spec calls out (`extractedText` coming
  back empty) is the Courses/upload feature's responsibility, not the
  Worker's — noted for whoever builds that.

  31 unit tests on the pure logic (`worker/test/generation.test.js`, run via
  `npm test` — `vitest` added as a worker devDependency), 0 failures:
  prompt building for both types (verified section-by-section, including
  that quiz never gets the flashcard-only sections and vice versa),
  multi-difficulty and multi-material substitution, the `max_tokens`
  cap actually clamping, `customPrompt` at exactly 300 vs. 301 characters,
  and shuffle preserving the same 4 options (just reordered) with
  `correctAnswer` untouched. The HTTP handler itself isn't covered by these
  (no real caller exists yet — Phase C's Quiz/Flashcard generation UI isn't
  built); `wrangler deploy --dry-run` still compiles cleanly.
- **Phase B — Shared UI:** in progress. Auth screens done (Welcome, Log In,
  Create Account, Forgot Password, Check Your Email), built from the
  `docs/mockups/android-study-app-redesign` Phase 0 design handoff. Built a
  new `AppTheme` design system from scratch (`lib/theme/`: colors,
  typography on Nunito via `google_fonts`, spacing/radius tokens) — the
  foundation every later screen should build on, not just auth. Password
  rule matches the mockup's own copy exactly: 8+ characters plus a digit;
  uppercase/lowercase/symbols allowed but never required (confirmed with the
  team over the initial CLAUDE.md draft's stricter phrasing). Forgot
  Password never reveals whether an email is registered — Firebase's
  `user-not-found` is caught in `AuthService.sendPasswordReset` and treated
  as success. Full unit/widget test coverage added per the new Testing
  requirements below: 46 tests (12 validator unit tests, 34 widget tests
  covering every state shown in the design), 0 failures — see
  `test/screens/` and `test/validators/`. Writing these tests caught three
  real bugs before they shipped: Login's error banner always showed the
  hardcoded "wrong credentials" text regardless of the actual failure (now
  varies by error type); Create Account's empty-password submit never
  rendered "Password is required" (the empty/non-empty branch only ever
  showed the hint or the strength bar); Check Your Email's cooldown showed
  the invalid "0:60" at the very first frame (now formats minutes properly).

  Home screen done next (Phase 1 design handoff, frames 1/2/2b — the Courses
  tab frames are deferred): greeting with real name, Today's Progress card
  with the study streak weekly row, Continue-or-Start card, Upcoming
  section, and the Home/Courses/Calendar/Profile bottom nav (the latter
  three are placeholder screens — Phase C). Two new `Student` fields, an
  approved deviation from the Attributes Dictionary Table (same pattern as
  `StudyMaterial.document`): `currentStreak` and `lastStudyDate`. Streak
  rules, confirmed with the team: entirely independent of week boundaries
  and of the points system; breaks only when a full local-calendar day
  passes with zero committed study activity; no minimum activity count to
  keep it alive; a session's activity is attributed to its `completedAt`
  date only (no new per-question/per-flashcard timestamps) and, once
  committed, is permanent — deleting the session afterward doesn't undo it.
  The write side (`StreakService.recordStudyActivity`) has no caller yet —
  nothing creates or completes a session until Phase C's Quiz/Flashcard
  generation exists — so it's built and fully unit-tested but unreachable in
  the running app today, same as the Resume-session flow and the course
  picker's course-selected action (both wired to placeholder screens ready
  for Phase C to swap in). `HomeDataService` follows the same injectable
  pattern as `AuthService`, so every Home state is covered by widget tests
  with fake data. 77 tests total now (0 failures) — see `test/services/` and
  `test/screens/home_screen_test.dart`. Writing the bottom-nav widget test
  caught a real layout bug that would have broken the running app, not just
  the test: the nav item's `Column` had no `mainAxisSize: MainAxisSize.min`,
  so it defaulted to `.max` and silently claimed nearly the entire screen
  height, squeezing the actual Home content down to zero height (invisible
  and untappable, though still "rendering" via overflow).

  **Post-merge fix:** on-device testing with a real fresh account
  ("student1") showed Home stuck on "Could not load your progress." Root
  cause confirmed by reproducing `HomeDataService`'s exact queries against
  the live project via the Firestore REST API (same method as Phase A's
  rules verification): `fetchWeeklyProgress` and `fetchInProgressSession`
  both filter `quizSessions`/`flashcardSessions` on `isSessionCompleted`
  while also range-filtering or ordering by a *different* field
  (`completedAt` / `createdAt`) — Firestore requires a composite index for
  that combination, and none existed, so both queries failed with
  `FAILED_PRECONDITION` even on an empty collection (a fresh account with
  zero sessions still hits this — it's a query-shape problem, not a data
  problem). The student doc read and the `events` query (a same-field
  range+orderBy, which Firestore auto-indexes) were both unaffected, which
  is why the name/points/nav rendered fine while progress didn't. Added
  `firestore.indexes.json` (4 composite indexes: `quizSessions` and
  `flashcardSessions`, each on `(isSessionCompleted, completedAt)` and
  `(isSessionCompleted, createdAt)`), wired it into `firebase.json`, and
  deployed with `firebase deploy --only firestore:indexes`. Re-verified the
  same three queries against the live project after the index finished
  building — all return 200 now. Any future query that filters on one field
  while ordering/range-filtering on another will need the same treatment —
  Firestore's error message always includes a direct link to create the
  missing index if one is only discovered at runtime.

  **Post-review correction:** a real gap was found in the first pass — a
  student with zero courses (Frame 1, "new student") is a third, distinct
  Home state, not just a variant of the Continue/Start card. It was in the
  original mockup read but never surfaced as a state needing its own
  scoping decision, unlike the Courses-tab frames, which were flagged as
  deferred on purpose. Fixed: zero courses now shows *only* the greeting +
  onboarding card (`NewStudentOnboardingCard`) — no Today's Progress, no
  streak row, no Upcoming section, no points badge — matching the mockup's
  Frame 1 exactly; all of that only renders once the student has at least
  one course. Frame 1's other two sub-states ("course created, now upload
  material" / "AI reading material") stay deferred — they depend on the
  Courses/upload flow itself.

  Also did a full precision pass against the raw `.dc.html` (hex colors,
  font sizes/weights, letter-spacing, shadows, radii, button heights) after
  it was flagged that some values had drifted from the source: fixed several
  font sizes that were defaulting to a shared text style's size instead of
  the mockup's actual value (e.g. 12px where the mockup wants 13px/14px),
  a `letterSpacing` meant for a 26px headline bleeding into smaller reused
  text, button heights that don't actually match one fixed value per variant
  across the app (56px on auth screens vs. 52px/58px on Home — `AppButton`
  now takes `height`/`borderRadius`/`borderColor`/`shadowColor` overrides),
  a hardcoded-navy button that should have been red, a missing footer
  caption in the course picker, and an `outlinedBrand` shadow that was fully
  opaque instead of the mockup's ~50% alpha. Also built a real dashed-border
  painter (`lib/widgets/dashed_border.dart`) for the streak row's
  empty/locked day cells — Flutter has no built-in dashed border, and a
  solid one would have been a visible approximation, not a match.
  Confirmed with the team: the streak row's TODAY cell only fills solid
  white once it has activity (a dashed bright-white outline before that,
  not filled), and a past day with zero activity uses the same dim
  dashed style as a locked future day (no mockup example either way,
  reasoned from the closest analogous state).

  **Font — now bundled, not fetched.** The running app was rendering in the
  system font (Roboto), not Nunito. Cause: `google_fonts` fetches font
  files over the network on first launch and *silently falls back to the
  system font* when offline — and nothing was bundled. Fix: dropped the
  `google_fonts` package entirely and bundled `assets/fonts/
  Nunito-VariableFont_wght.ttf` (one variable-weight file, full charset,
  SIL OFL — `OFL.txt` alongside it) via pubspec `fonts:`. `app_theme.dart`
  and `app_typography.dart` now use plain `TextStyle(fontFamily: 'Nunito')`
  / `ThemeData(fontFamily: 'Nunito')`; every screen's text (including the
  auth screens' `RichText` footer spans, whose root span carries an
  `AppTypography` style) resolves to Nunito with no network dependency.
  Design-file provenance, verified for the audit: the auth screens
  (Welcome/Login/Create Account/Forgot Password/Check Your Email) are built
  from `Tadarab Phase 0 - Auth.dc.html` only — 56px buttons, white frame
  backgrounds, no Phase-1 strings leaked in; the Home screen is built from
  `design_handoff_phase1/Tadarab Phase 1 - Home & Courses.dc.html` only —
  52/58px buttons, `#F7F8FD` background. No mixing between the two files.

  **Auth screen background — now pure white.** All five auth screens were
  inheriting the theme's `scaffoldBackgroundColor` (`AppColors.background`,
  then `#F0F1F7` — which is actually the Phase 0 file's *design canvas*
  colour, not a screen background). Every auth frame in that file is
  `background:#FFFFFF`. `AppColors.background` is now `#FFFFFF` (its only
  consumer is the theme default); Home keeps its own `homeBackground`
  (`#F7F8FD`). Covered by `test/theme/app_theme_test.dart` (font asset
  loads, theme + every `AppTypography` style is Nunito, bare `TextStyle`
  inherits it, default scaffold bg is white) and a WelcomeScreen bg test.
  89 tests, 0 failures.

  Remaining for Phase B: none. The Courses tab is out of scope for Phase B —
  it's Manar's Courses & Material upload feature (`feature/courses`, see
  Feature split) in Phase C, for her to define once she starts it.
- **Phase C — Feature split:** in progress.

  **Courses & Material upload** (Manar, `feature/courses`) — starting, per
  `courses_material_upload_spec.md` at the project root. Model deviation
  reported per that spec before writing the class: `StudyMaterial` gains a
  new `extractedText` (String) field, not in the original Attributes
  Dictionary Table — the plain-text extraction of the uploaded file's
  content, tagged with `[Slide N: ...]` / `[Heading N: ...]` / `[Paragraph
  N]` markers per the spec's exact contract with Ghaida's generation Worker.
  Final field set: `materialID, title, type, document, courseID,
  extractedText`.

  Text extraction library choice, per the spec's instruction to test the
  suggested packages on real files before committing: neither suggested
  package fit. Verified directly against `docs/Lecture1.pptx` and
  `docs/SRS_GP1...docx` (real files) plus each package's actual source/docs
  on GitHub — `open_xml`'s `WordDocument.parseText()` yields a flat stream
  of text runs with no paragraph-style info, so it can't tell a `Heading1`
  paragraph from body text; its `.pptx` support is generation/template-
  focused with no documented API for reading arbitrary slide text. 
  `doc_text_extractor`'s "chapter splitting" feature isn't exposed in its
  documented API, and it pulls in `syncfusion_flutter_pdf` for a PDF path
  this feature doesn't need. Inspecting the real files' raw XML showed the
  structure needed is simple and well-defined (PPTX: `<p:ph type="title"/>`
  marks a slide's title shape; DOCX: `<w:pStyle w:val="HeadingN"/>` marks a
  real heading, distinguishable from `TOC1-3`/`Caption`/`Bibliography`
  styles that share similar formatting but aren't headings) — so
  `lib/services/text_extraction_service.dart` parses PPTX/DOCX/TXT directly
  with the `archive` (unzip) and `xml` (parse) packages, the same
  lower-level packages both suggested libraries build on. This gives exact
  control matching the spec's tagging contract instead of adapting to
  either library's undocumented behavior.

  **Built out.** `lib/services/courses_service.dart` (course/material CRUD,
  cascade delete — course doc + materials subcollection + their Storage
  files + this course's calendar events, per §3 — the direct
  `users/{uid}/events` query/delete written inline since Leen's
  `CalendarService.deleteEventsForCourse(uid, courseId)` isn't merged yet;
  swap the call site once it is), the 4 screens (`lib/screens/courses/`:
  courses list empty/list states, Add Course as a full pushed screen per
  the design handoff — confirmed with the team over the mockup's own
  `upload-material.png` frame, which is a lower-fidelity draft that
  disagreed with the actual `.dc.html` handoff — Course Detail
  locked/unlocked, and the Upload Material bottom sheet), and the delete
  confirmation dialog. `file_picker`/`archive`/`xml` added as dependencies.
  10MB file-size limit used everywhere per §8's default, with the 10 vs
  20MB conflict still flagged and unresolved for the team. Routing: the
  single authorized line in `lib/screens/home/home_screen.dart` (Courses
  tab → `CoursesListScreen`) swapped in its own commit, per §9.

  136 tests, 0 failures: 15 extraction unit tests (including against the
  real `docs/Lecture1.pptx`/SRS `.docx`), 14 pure-logic unit tests (name/
  material-name uniqueness, color-lock incl. freeing on delete, initials),
  and 18 widget tests covering every state §10 lists (empty, list, Add
  Course incl. duplicate-name/no-color-disabled, Course Detail locked/
  unlocked, Upload Material idle/uploading/success/duplicate/empty-file-
  error, delete confirmation).

  **On-device verification**, per CLAUDE.md's standing rule to actually
  exercise UI changes rather than rely on tests alone: run against the real
  `tadarabapp-2e060` project on a local Android emulator (`sdk gphone64
  arm64`, API 36), signed in as the existing `student1` test account.
  Confirmed live: the Courses tab renders the real screen (not the old
  placeholder); the empty state, Add Course's live validation (duplicate-
  name warning, color lock/select, live preview), and course creation all
  worked end-to-end — a real `IS230` course document was written and
  persisted (confirmed indirectly: Home switched from the zero-courses
  onboarding state to the has-courses state on the next launch).

  This surfaced one real bug, now fixed: `CoursesService`'s Firestore/
  Storage calls (`createCourse`, `deleteCourse`, `uploadMaterial`, the list/
  materials fetches) had no timeout. The emulator's network went
  genuinely flaky mid-session (confirmed via `adb logcat`: real
  `UnknownHostException` resolving `firestore.googleapis.com`, and a bare
  `ping 8.8.8.8` from the emulator shell hung with no reply — a sandbox
  network limitation, not a code issue), and a `createCourse` write hung
  for 30+ seconds with the Save button stuck spinning and no way out —
  exactly what the NFR's "never a frozen screen" rule exists to prevent.
  Added a 15s timeout on every Firestore call and a 60s timeout (with
  `UploadTask.cancel()`) on the Storage upload specifically, since a real
  file transfer legitimately needs more headroom than a small document
  write; both map to the existing `CoursesFailure` error path. Re-verified
  live after the fix: the Courses list now shows "Couldn't load your
  courses." with a working Retry button within the timeout window instead
  of hanging — confirmed by triggering the same network condition again.

  **Upload and cascade-delete verification, completed in a follow-up
  on-device pass** after the emulator's network fully stopped responding
  (confirmed: DNS resolution failed for every hostname, not just
  `firestore.googleapis.com`, and the emulator's own network settings
  (private DNS off, wifi/airplane-mode toggles) didn't fix it, while the
  host machine's own DNS/`curl` to the same hosts worked fine throughout —
  isolating the problem to the emulator's QEMU/slirp networking layer, not
  the code, the project, or the host). Fixed by killing and relaunching the
  AVD (`Pixel_10_API_36`) with explicit `-dns-server 8.8.8.8,8.8.4.4`.

  With real network restored: pushed `docs/Lecture1.pptx` to the
  emulator's Downloads folder, opened Upload Material, picked it through
  Android's real system file picker (not a stub), watched a real Storage
  upload progress bar, and — confirmed by reopening Course Detail — the
  material was actually written: Study Tools unlocked, the materials list
  and type-filter counts (`All 1 / PPTX 1`) updated, all against the live
  `tadarabapp-2e060` project.

  This caught a second real bug, now fixed: both `CoursesListScreen` and
  `CourseDetailScreen`'s `_reload()` used
  `setState(() => _field = someFuture)` — an assignment expression as an
  arrow-function body evaluates to the assigned value, so the callback's
  inferred return type was `Future<...>` instead of `void`. In debug
  builds this trips `State.setState`'s "callback argument returned a
  Future" assertion, which *throws before reaching `markNeedsBuild()`* —
  caught by `adb logcat` right after a successful upload, where it made
  Course Detail appear to silently fail to refresh (the material had in
  fact saved; the screen just didn't reliably rebuild to show it). Fixed
  by using a block body (`setState(() { _field = future; })`) in both
  places, which returns `void`. Confirmed fixed by re-running the exact
  same upload afterward. Note for the team: this class of bug is silent in
  release builds (`assert` is compiled out there), so it's easy to miss
  outside an on-device debug run — worth checking for the same
  `setState(() => x = someFuture)` pattern in any future feature's reload
  logic.

  **Cascade-delete verification, including calendar events**, done against
  a throwaway account rather than reusing `student1`, since the Calendar
  feature doesn't exist yet to create a real linked event through the UI:
  created a temporary account via the Identity Toolkit REST API (the same
  method Phase A's rules verification used), wrote a course, a material,
  and a calendar event (with `courseId` pointing at that course) directly
  via the Firestore REST API, logged into the app as that account, and
  deleted the course through the real UI delete-confirmation flow. Verified
  by re-querying all three documents over the Firestore REST API
  afterward: course, material, and **event all returned `404 NOT_FOUND`**.
  The event-deletion path in particular — invisible in the app's own UI
  today, since there's no Calendar screen yet to show its absence — is now
  confirmed working end-to-end against the live project, not just via the
  widget tests' fake service. The throwaway account and its data were
  deleted afterward (Identity Toolkit `accounts:delete`); `student1` and
  its real `IS230` course (with its one uploaded material) were left
  intact for any future manual testing.

  Every state/flow this feature spec calls for has now been confirmed both
  by the automated test suite and by a real run against the live Firebase
  project: courses empty/list, Add Course validation, Course Detail locked/
  unlocked, the full upload pipeline (real file → Storage → extraction →
  Firestore) with the real `docs/Lecture1.pptx`, and cascade delete
  including calendar events.

  **Home-screen regression investigated and ruled out as unrelated to this
  feature.** After the above was done, `student1`'s Home tab started
  showing "Could not load your progress" with a working connection and a
  successful login. Confirmed by direct A/B test — `git stash` on just
  `lib/screens/home/home_screen.dart` (reverting it to the exact
  pre-Courses version, i.e. the Courses tab back to
  `PlaceholderScreen`) and relaunching against the same account
  reproduced the *identical* error — that neither this feature's one-line
  routing change nor the `_reload()` fix touches this code path or caused
  it. Root-caused (via temporary, since-removed debug prints — never
  committed) to a plain Dart type error, not a network/Firestore
  exception: `type 'Null' is not a subtype of type 'String' in type
  cast`, thrown from `HomeDataService.fetchInProgressSession` and
  `fetchWeeklyProgress` specifically (`fetchCourses` and
  `fetchUpcomingEvents` succeed fine) — both go through
  `SessionFields.fromMap` (`lib/models/session.dart`), which casts
  `difficultyLevel`, `email`, and `courseId` as non-nullable `String`
  with no fallback. `student1` has real documents in both `quizSessions`
  and `flashcardSessions` that are missing one of those fields (confirmed
  via the Courses tab loading fine with "2 courses" — Manar's own
  `IS230` plus a second, "data base", that Manar created herself through
  this feature's real UI while testing it, unrelated to the session
  documents). The session documents themselves can't have come from using
  the app, though: grepping the whole codebase shows `HomeDataService` is
  the *only* code anywhere that touches the `quizSessions`/
  `flashcardSessions` collections, and it only ever reads (`.get()`) —
  there is no writer, since Quiz/Flashcard generation (Ghaida's and
  Deemah's Phase C features) hasn't been built yet. So the malformed
  document(s) must have been added some other way — most likely by hand
  via the Firebase console, by someone testing Home's Continue/Start or
  Today's Progress card early, before generation existed to write real
  ones — and is unrelated to Manar's own course-creation testing. This is
  a pre-existing gap in shared, frozen model code (`lib/models/
  session.dart` — not this feature's file, and not safe for a single
  branch to change without full-team review per the Git workflow rules)
  that any malformed session document was always going to trip; it
  surfaced now by coincidence of timing, not because of anything in this
  feature.
  **Not fixed here** — flagged for the team: either harden
  `SessionFields.fromMap`'s three casts the same way `Course.fromFirestore`
  already does for `color` (nullable with a fallback), or delete/fix
  whatever hand-created `quizSessions`/`flashcardSessions` documents
  `student1` has via the Firebase console.

  **Two more real bugs found on-device and fixed**, both stemming from the
  same root cause: `HomeScreen`'s `IndexedStack` keeps every tab's State
  alive and independent, so nothing ever told a tab to refresh once
  another tab (or a screen pushed on top of one) changed the data it had
  already fetched.
  1. Home's onboarding "Create my first course" button opened the real
     `AddCourseScreen` (per the fix above) but never awaited its result —
     `_HomeTabState._openAddCourse` called `Navigator.push` without
     awaiting, so a successful save's `Navigator.pop(true)` returned to
     Home with nothing done about it: no refresh, and the newly-created
     course invisible until something else happened to trigger one.
  2. Switching to the Courses tab after creating a course elsewhere showed
     stale data (sometimes an empty list) because `CoursesListScreen`'s
     `late Future ... _courses = ...` only ever fetches once, at
     construction — which, since `IndexedStack` builds every child up
     front, happens once at Home's very first frame, not each time the
     tab becomes visible.

  Fixed both with the same mechanism: `_HomeTab` and `CoursesListScreen`
  each gained an `active` flag (true only while its own bottom-nav tab is
  selected) and a `didUpdateWidget` that reloads on `active` flipping
  false→true — so switching tabs now refreshes whichever tab you land on,
  symmetrically in both directions. `_openAddCourse` now also awaits its
  `Navigator.push` and reloads immediately on a successful create, so
  Home updates the instant you're popped back to it, without needing a
  tab switch at all. `HomeScreen` gained an injectable `coursesService`
  (mirroring the existing `homeDataService` override), since both the
  onboarding button and the embedded Courses tab needed one and it's what
  made these regressions properly testable — this was the one further
  change to this frozen file beyond the button-routing fix above; flagged
  the same way, its own commit when this lands.

  4 new tests reproducing each bug's exact repro steps against the real
  screens (fakes only at the network boundary) and confirming the fix: in
  `courses_list_screen_test.dart`, a course added while inactive appears
  on becoming active again, and staying active doesn't cause a needless
  refetch; in `home_screen_test.dart`, creating a course through the
  onboarding button both returns to Home and lifts it out of onboarding,
  and a course created while Home was the inactive tab appears on
  returning to it. 140 tests total, 0 failures. Not re-verified live on
  the emulator this round (the fix is a pure navigation/reload wiring
  change with no new Firebase interaction shape, and the regression tests
  drive the real screens end-to-end down to the fake network boundary) —
  worth a quick manual pass before merging given how much this session's
  device testing has been worth in general.

  **Two visual bugs in the Upload Material sheet**, caught live on-device
  and fixed, both confined to `upload_material_sheet.dart` (no frozen-file
  touch): the Upload button rendered navy instead of red — it never set
  `variant: AppButtonVariant.accent`, silently falling back to `AppButton`'s
  navy default — and now also dims to a pale red (`Opacity` at 0.4) while
  disabled and goes full solid red once a file's picked, matching the
  pattern already used for the locked Study Tools tiles and locked color
  swatches, since `AppButton` itself has no disabled-vs-enabled visual (it
  only dims for its separate `loading` state). The "Choose a file"
  drop-zone's dashed border was being drawn but was completely invisible:
  its opaque `surfaceFaint` fill lived on `DashedRoundedBorder`'s own
  child, and `CustomPaint` draws its `painter` *behind* the child — so the
  fill painted over the dashes it was meant to sit inside. Moved the fill
  to a new outer `Container` wrapping `DashedRoundedBorder` instead,
  leaving its child transparent; `DashedRoundedBorder` itself
  (`lib/widgets/dashed_border.dart`) wasn't touched. Both fixes verified
  live on the emulator (idle-pale, empty-file-picked-solid, dashes visible
  throughout).

  **Delete single material**, a new feature request (deleting one study
  material without deleting its course), scoped and confirmed with the
  team before coding per the standing rule. `CoursesService.deleteMaterial`
  deletes just that material's Firestore doc, then best-effort-deletes its
  Storage file (mirroring `deleteCourse`'s per-material cleanup) — it
  never touches the course doc, any other material, or any quiz/flashcard
  session, on purpose (out of scope unless asked). UI:
  `delete_material_dialog.dart` mirrors `delete_course_dialog.dart`'s
  structure/copy exactly ("Delete [name]?" / "This material will be
  permanently deleted. This can't be undone." / red "Delete material" +
  outlined "Keep it"), kept as its own file rather than sharing one with
  the course dialog so that already-verified flow stays untouched. Each
  material row in Course Detail now has its own trash icon — navy on the
  same pale tint used by the row's own PPTX/DOCX/TXT type badge, per an
  explicit correction from the initial plan (which had proposed red,
  reasoning from an old removed courses-list design reference) — that
  turns into a small spinner while that specific material is deleting, via
  a per-row `Set<String>` of in-flight material IDs on
  `_CourseDetailScreenState` rather than one screen-wide flag, so deleting
  one material doesn't freeze the rest of the list. On success the list
  updates immediately in place (no navigation away from Course Detail); on
  failure, the existing SnackBar+Retry pattern used elsewhere in this
  feature. 6 new widget tests added to `course_detail_screen_test.dart`
  (trash icon present per row, tapping opens the dialog with the correct
  material name, "Keep it" is a no-op, confirming deletes and updates the
  list without navigating away, a failure shows the SnackBar with Retry
  and leaves the row in place, deleting the last material re-locks Study
  Tools and shows the empty-materials state) plus the matching
  `FakeCoursesService.deleteMaterial` override. 146 tests total, 0
  failures. Not yet re-verified live on the emulator for this specific
  feature.

## Design handoffs

- `docs/mockups/android-study-app-redesign/` — Phase 0 (Auth: Welcome, Log
  In, Create Account, Forgot Password) is implemented. Phase 1 (Home &
  Courses) is in the same bundle: the Home frames are implemented. The
  Courses-tab frames are Manar's Courses & Material upload feature
  (`feature/courses`, see Feature split) — not yet built, and hers to scope.
