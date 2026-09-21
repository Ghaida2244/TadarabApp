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
- **Phase C — Feature split:** Deemah's Flashcards & Sessions
  (`feature/flashcards`, rebased onto latest `main` — picked up the Phase B
  Home work and the AI generation Worker) is done except the live Worker
  call. No Phase B UI existed for this feature yet (checked the working
  tree, `main`, and the pre-existing `feature/flashcards` branch — none had
  it), so this pass built the screens too, not just the logic layer, styled
  with the existing `AppTheme` and informed by
  `docs/mockups/design_handoff_flashcard/.../Tadarab Phase 2b -
  Flashcards.dc.html` and its reference PNGs, but this was not a
  pixel-precision design pass like Phase B's.

  **Model changes** (audited against `docs/Attributes Dictionary Table.png`
  first, per the required audit — full match on every other field):
  `Session.difficultyLevel` → `difficultyLevels: List<DifficultyLevel>`
  (non-empty assert), affecting `session.dart`, `quiz_session.dart`, and
  `flashcard_session.dart` alike since `QuizSession` and `FlashcardSession`
  share the base class — **a teammate may be making this same change
  independently; expect a merge conflict on `session.dart`/
  `quiz_session.dart` to resolve manually, not a bug.**
  `FlashcardSession.materialTitles: List<String>` added (approved
  deviation, same pattern as `StudyMaterial.document`) so the Sessions list
  can show a session's material badge without a materials re-fetch.
  `Flashcard.reviewStatus` changed from required to nullable (`ReviewStatus?`)
  — needed for a freshly-generated card's pre-review state and for Retake's
  reset, since the enum itself stays exactly `{knowIt, needsReview}` as
  specified. `Flashcard.cardIndex: int` added (approved deviation) — Firestore
  doesn't preserve document insertion order, but Resume must reopen a deck in
  its original order and Retake must persist a freshly-shuffled order, so an
  explicit, independently-rewritable position field per card was the only way
  to support both.

  **Worker call — still a placeholder.** `FlashcardService.generateFlashcards`
  throws `UnimplementedError` exactly as specified; the Worker's live URL
  hasn't been provided. Every other outcome (success at full count, short
  result → limit dialog, any failure → retry-able banner) is wired and
  tested against a fake service, so swapping in the real HTTP call later
  should only require rewriting that one function's body.

  **Message copy**: per instruction, did *not* touch auth_service.dart's
  `_networkFailureMessage`/`_genericFailureMessage` (a teammate may be
  actively editing that file) — `flashcard_service.dart` instead duplicates
  the exact same text as its own public `kFlashcardNetworkFailureMessage`/
  `kFlashcardGenericFailureMessage`, with a TODO to consolidate onto
  auth_service.dart's constants once that file is confirmed safe to touch.

  **New files**: `lib/services/flashcard_service.dart` (Firestore CRUD +
  the Worker-call placeholder), `lib/features/flashcards/logic/
  flashcard_logic.dart` (pure functions: points, tier selection, resume-index
  clamping, Retake reshuffle+reset, delete-dialog body text — no Firestore
  dependency, matching how `home_data_service.dart`'s pure helpers are
  tested), five screens and five shared widgets under
  `lib/features/flashcards/`. Did not touch `home_screen.dart` — it still
  opens placeholders for flashcard setup/resume; wiring real navigation
  there is shared/Phase-C-sensitive territory and wasn't asked for here.

  55 new tests (21 unit on `flashcard_logic.dart`, 34 widget across the five
  screens and five widgets — Generating overlay, limit dialog, empty
  sessions list, all four progress-pip states, save-and-leave sheet, Review
  Pass button-label logic including the single-card case, both delete-dialog
  variants, all three Performance Summary tiers at their exact 50%/80%
  boundaries, and Review-now visibility), 0 failures. Full suite: 144 tests,
  0 failures. `flutter analyze` clean except two pre-existing infos
  (`session.dart`'s assert form was specified verbatim; the
  `auth_service.dart` doc-comment lint predates this work).

  **Visual rebuild pass** (pure styling, no state/logic changes): the first
  pass above was a reasonable approximation, not sourced from the actual
  design files. Rebuilt all 5 screens + widgets against `docs/mockups/
  design_handoff_flashcard/.../design_handoff/Tadarab Phase 2b -
  Flashcards.dc.html` and its README, made the single source of truth for
  this pass (screenshots deliberately excluded — the interactive prototype
  and screenshots disagreed with each other in several places, e.g. header
  colors on Sessions/Setup, so screenshots were dropped rather than
  cross-referenced further).

  Explicit decisions confirmed before rebuilding, overriding what the
  hand-off alone would give: tier message copy stays the existing
  research-cited text ("You've mastered this." etc. — Bloom 1968; Mueller &
  Dweck 1998), not the handoff's own wording; stat-card labels stay "I know
  it"/"Need review"; tier background colors are green/purple/pink (see
  below re: "purple"); Review Pass reuses the Flip Deck's pip strip, not a
  bar; Review Pass's "Next" is red; the Sessions header is a two-part
  "Flashcards" + dimmer live count; new pip colors for the Flip Deck
  (`#7BE0A0` known, white-alpha for needs-review/untouched); a "Retake
  Flashcards" button was added to Performance Summary (a real behavior
  addition, not just styling — done because it was explicitly requested and
  the underlying `retake()` call already existed).

  New color tokens needed by the handoff were kept **local to the Flashcards
  feature files**, not added to `AppColors`/`AppTheme` — those are on
  CLAUDE.md's frozen-shared-file list and a teammate may be mid-edit, same
  reasoning as the earlier `kFlashcard*FailureMessage` duplication.

  Two things this pass could not fully deliver, both flagged with inline
  TODOs rather than silently approximated:
  - **`AppButton` has no "disabled but not loading" visual state** (only
    `loading`, which is grey) and no background/text-color override — so
    the handoff's pink-fill (`#F3A8AC`) disabled Generate button, and a
    true green-filled "I know it" / white-with-red-ink "Need review" pair,
    aren't reachable through its public API. Per instruction,
    `lib/widgets/app_button.dart` was **not** touched (possible teammate
    collision). The Flip Deck's two verdict buttons are instead small
    local, non-shared widgets (`_VerdictButton`) that hit the exact colors;
    Generate's disabled state approximates by dropping the shadow and
    showing the same reason text, with fill staying red instead of pink.
  - **The handoff's front-face "EXAMPLE" panel and per-card "topic" tags
    (Performance Summary's "Marked for review" chips) have no backing
    field on `Flashcard`** — neither is in the Attributes Dictionary Table,
    and neither was requested when the model was built. Both are omitted
    rather than fabricated; flagging in case a future pass wants to add
    them as an approved model deviation.

  One correction made mid-pass, worth a teammate's attention if they touch
  this screen: the handoff's "developing" (50–79%) tier is actually a light
  navy/lavender tint (`#EEF0FF` + navy ink), not purple — the prior purple
  (`#F3E8FF`) was this project's own invented color, not sourced from any
  design file. Implemented the verified navy/lavender value instead.

  Also fixed a real layout bug surfaced by the rebuild (not a visual
  choice): the Sessions list's colored side-strip used `Row(
  crossAxisAlignment: CrossAxisAlignment.stretch)` inside a `ListView`
  (unbounded height), which is a circular layout dependency — Flutter threw
  thousands of `RenderFlex`/`debugCheckForParentData` assertion errors and
  every session-row widget test hung on `pumpAndSettle`. Fixed by wrapping
  the row in `IntrinsicHeight`, the standard pattern for a "strip spans
  full row height" layout when the row's own height isn't otherwise
  bounded.

  Updated 2 existing tests to match the deliberately-changed visual
  behavior above (pip "known" color; the flip card's answer-side no longer
  has a "FIND IT IN YOUR MATERIAL" heading, per the handoff). Full suite:
  144 tests, 0 failures. `flutter analyze` clean (same two pre-existing
  infos as above).

  **Deliberate, explicit overrides of the .dc.html** (confirmed twice after
  re-verifying the file showed otherwise both times — these are intentional
  exceptions, not drift, and should not be "corrected" back to match the
  file without the team re-discussing it): Sessions List and Setup screen
  headers are **red** (`AppColors.red`), not the file's navy; the Setup
  header reads **"Flashcard setup"**, not the file's "Build the deck"; the
  Sessions List row's **"DECK" badge is removed**; the count-stepper's "A
  target, not a promise — the AI writes as many good cards as your
  material supports." helper line (present verbatim in the current
  `.dc.html`, line 165) is **removed**. Materials picker still shows a
  plain "N materials selected" / single-title summary, never a list of
  titles — this one actually matches the current `.dc.html`. 55 flashcards
  tests, 0 failures after these changes; full suite not re-run this pass
  (no non-flashcards files touched).

  **Reversal:** the "Retake flashcards" button added to Performance Summary
  earlier in this same pass (to match the `.dc.html`) has been **removed
  again** — Retake now lives only on the Sessions List, per explicit
  instruction, so there's one place it can be triggered from, not two.
  Also removed the "2 per card you knew" subtitle under "Points earned" —
  that row now shows just the label and the number. 4 performance-summary
  tests, 0 failures; `flutter analyze` clean.

  **Five more UI tweaks**, on-device-testing feedback rather than
  design-handoff conflicts:
  - Sessions List: a session's material title(s) are now a pill badge
    above the status row (was plain grey text below the stats line); if
    the joined title text is wider than the pill, it loops in a continuous
    horizontal scroll (`_MarqueeText`) instead of wrapping or eliding.
    **Real bug hit and fixed while building this:** the first version used
    a `LayoutBuilder` to detect overflow, but this session row sits inside
    an `IntrinsicHeight` (added earlier for the colored side-strip) —
    `LayoutBuilder` inside an intrinsic-sizing pass throws a storm of
    `RenderFlex`/`debugCheckForParentData` assertions and hangs
    `pumpAndSettle`, the same failure mode as the `IntrinsicHeight` bug
    fixed in the visual rebuild pass. Fixed by measuring the rendered width
    via a `GlobalKey` + `RenderBox` read in a post-frame callback instead —
    the first build is always a plain, intrinsically-safe `Text`, and only
    a later frame (outside any intrinsic pass) can switch to the scrolling
    layout. Note for later: the marquee's `AnimationController` repeats
    forever once scrolling starts, so any future widget test that calls
    `pumpAndSettle()` on a row whose title is long enough to actually
    scroll will hang the same way — none of the current tests trigger it
    (their sample titles are short), but it's a trap for a longer one.
  - Setup screen: "Medium" is now selected by default (still freely
    changeable) instead of requiring the student to pick a difficulty
    before anything is selected.
  - Setup screen: the "Generate flashcards" button now genuinely fills
    pink (`#F3A8AC`, the README's own documented disabled-red-fill token)
    when disabled, closing the gap the TODO from the visual-rebuild pass
    flagged. Required a small, additive extension to the shared
    `lib/widgets/app_button.dart`: a new optional `disabledBackgroundColor`
    param, applied only when the button is disabled-and-not-loading — every
    other existing `AppButton` call site across the app omits it and is
    therefore unaffected (verified: analyzed and tested the whole project,
    not just Flashcards, after this change).
  - Setup screen: the cards-to-aim-for count is now directly editable
    (tap the number, type a value on the numeric keypad) alongside the
    existing +/- buttons; invalid or empty input reverts to the last valid
    value, and typed values respect the same bounds as the buttons. The
    LinearProgressIndicator bar under the count was removed.
  - Setup screen: count bounds changed from 3–20 to 5–150 (the visual
    rebuild pass had already changed the original 1–50 to 3–20; this
    changes it again).

  55 flashcards tests, 0 failures (one test updated — "Generate button is
  disabled" now accounts for Medium starting pre-selected — and the intent
  preserved, not just made to pass). Full project suite re-run after the
  shared `AppButton` change: 144 tests, 0 failures; `flutter analyze` clean.

  **Fix: the material-title pill's marquee never actually triggered.** The
  pill's `Container` was `width: double.infinity`, so it always stretched
  to the full card width — nothing ever overflowed it, so the "scrolling"
  branch was dead code in practice. Fixed by giving the pill a real fixed
  `ConstrainedBox(maxWidth: 200)` (`_kMaterialPillMaxWidth`, tunable) and
  rewriting `_MarqueeText` to compare the text's natural width against
  that fixed number directly in `build()`, rather than measuring the
  parent's rendered width at runtime — simpler, and sidesteps needing
  `LayoutBuilder` or a post-frame `RenderBox` read entirely (both of which
  have their own problems inside this row's `IntrinsicHeight`, per the
  earlier note). Verified with two new tests, not just visual inspection:
  one confirms a short title renders once with no `Positioned` (the
  scrolling branch's tell), the other confirms a long joined title renders
  twice (the loop + its follow-on copy) *and* that a `Positioned`'s `left`
  offset actually changes between two pumps — proving real motion, not a
  silent fallback to a wider box.

  This exposed the trap flagged in the note above: the existing
  "singular session count" / "in-progress" / "completed" row tests all use
  the same default sample title ("Lecture 1 - Introduction"), which turned
  out to be wide enough at the new fixed pill width to trigger scrolling —
  so their `pumpAndSettle()` calls started hanging on the marquee's
  infinite-repeat animation. Switched those three to a plain `pump()`
  (they were never actually testing the marquee, just text/button
  presence, so this loses nothing). General lesson for this row going
  forward: **never call `pumpAndSettle()` on it — use `pump()`** — whether
  a given title triggers the marquee depends on exact text-measurement
  behavior that can differ between the test harness's font fallback and a
  real device, so it's not safe to assume "short enough not to scroll"
  will hold.

  57 flashcards tests now (2 new), 0 failures. Full project suite: 146
  tests, 0 failures; `flutter analyze` clean.

  **Two more refinements to the pill, and its mechanism changed entirely.**
  The fixed `_kMaterialPillMaxWidth` (200px) approach above was itself
  wrong: the ask was for the pill to hug short content and grow only up
  to the *card's* full width (not a flat constant), and — this is the
  bigger change — for long content to be **manually drag-scrollable**,
  not auto-looping. So `_MarqueeText` (`AnimationController`, the
  `Positioned` duplicate-loop) is gone; `_MaterialTitlePill` replaces it:
  hugs content via `Align` inside an invisible full-width sizing box (so
  short titles don't stretch), and once text is wider than that box's
  *measured* available width, becomes exactly that width with a plain
  horizontal `SingleChildScrollView` inside — the user drags to see the
  rest. Still reads the available width via `GlobalKey` + `RenderBox` in
  a post-frame callback rather than `LayoutBuilder`, for the same
  `IntrinsicHeight` reason as before.

  Also moved the delete/trash icon out of the pill's line entirely — it
  now sits beside the status-dot/detail-text block below (its original
  position before the pill existed), so the pill's available width isn't
  reduced by a sibling it no longer shares a `Row` with.

  Rewrote the two marquee-behavior tests to match: one confirms a short
  title introduces no `SingleChildScrollView` at all (hugging, not always
  a fixed box); the other confirms a long joined title produces exactly
  one horizontal `SingleChildScrollView` *and* that dragging it actually
  moves its `ScrollableState.position.pixels` away from zero — proof it's
  really draggable, not just present. 57 flashcards tests (same count,
  2 replaced in place), 0 failures. Full project suite: 146 tests, 0
  failures; `flutter analyze` clean.

  **`FlashcardCard` (Flip Deck + Review Pass): fixed size, and two source-
  strip corrections.** Re-verified directly against the current `.dc.html`
  before changing anything, per the standing rule — two findings worth
  recording:
  - The handoff's source-location strip is `#EEF0FF` (a light navy tint)
    with navy text/icon, **not** a navy background as it was described
    when this request came in. Kept `#EEF0FF`, per the file. The existing
    doc comment claiming the handoff has no "FIND IT IN YOUR MATERIAL"
    heading was also double-checked directly against the file and found
    to be accurate, not stale — left as-is. Two real (smaller) mismatches
    were found and fixed: the strip's border-radius should be 16px (was
    14, i.e. `AppRadius.md`), and its icon+text should be left-aligned
    (was centered — the handoff's flex row has no `justify-content`,
    which defaults to start).
  - The handoff itself has **no fixed card size at all** — the card is
    fluid (`width:100%` of its container, height auto-sized to content),
    so front/back and short/long content render at different sizes there.
    Treated the fixed-size ask as a deliberate choice for this app (fair
    one — a card changing shape between its two faces reads as a glitch),
    sized off the handoff's own reference phone frame: 412px wide minus
    22px of deck-body padding on each side ≈ 368px available, so 320×320
    (`_CardFace._size`) is a round number comfortably under that. Content
    now overflows via an internal vertical scroll
    (`SingleChildScrollView` + `ConstrainedBox(minHeight: ...)` +
    `Center`) rather than growing the card — short content still centers
    vertically when there's nothing to scroll. `FlashcardCard` isn't used
    anywhere inside an `IntrinsicHeight` (verified: that's Sessions-List-
    only), so `LayoutBuilder` was safe to use here, unlike the sessions
    row.

  Added 3 new tests verifying this isn't just visual: front and back
  render at the exact same `Size(320, 320)` regardless of text length;
  very long text throws no render-overflow exception and the card stays
  fixed-size while its internal `Scrollable` has genuine
  `maxScrollExtent > 0`; short text's vertical center lands close to the
  card's own center (not pinned to the top). 60 flashcards tests now
  (3 new), 0 failures. Full project suite: 149 tests, 0 failures;
  `flutter analyze` clean.

  **Explicit, deliberate departure from the handoff, requested directly
  (no re-verification asked or done for this one):** the back face's
  source-location strip is now navy (`AppColors.navy`) with a white icon
  and two stacked white lines — a dim "FIND IT IN YOUR MATERIAL" label
  above a bold location line — replacing the handoff's own `#EEF0FF`-
  tint/no-heading version from the visual rebuild pass. The strip has an
  explicit fixed height (`_kSourceStripHeight`, 62) so it can't grow with
  a long location string; both text lines are capped at `maxLines: 1` +
  `TextOverflow.ellipsis` instead. Also increased `_CardFace._size` from
  320 to 352 (bigger, per request, still fixed/square) — sized against
  the actual `Padding(all: 22)` both hosting screens use (44px fixed
  horizontal budget) and the handoff's own 412px reference frame (~368px
  available), leaving a 16px margin.

  Added a `ValueKey('source-strip')` for test targeting, and 2 new tests:
  the strip renders at the identical size for a short vs. a very long
  location (proving it truly doesn't grow), and the location `Text`
  widget's own `maxLines`/`overflow` properties are asserted directly
  (not just eyeballing that it looks truncated). Updated the two existing
  fixed-card-size test assertions from `Size(320, 320)` to `Size(352,
  352)`, and the "flipped" test's stale "no heading" comment/assumption —
  it now asserts the heading *is* present, matching the new deliberate
  design. 62 flashcards tests now (2 new), 0 failures. Full project
  suite: 151 tests, 0 failures; `flutter analyze` clean.

  **Correction to the strip above:** it had been made full card width,
  which was wrong — precise spec given directly (no re-verification asked
  for this one, since it's an intentional handoff departure): narrower
  than the card (`_kSourceStripWidth = 230`, ~74% of the card's 312px
  inner content width), horizontally centered (free via the surrounding
  Column's default center cross-axis alignment once the strip stopped
  being `width: double.infinity`), height brought down from 62 to 54,
  radius from 16 to 14, icon 20→17, icon-to-text gap 12→9, inter-line gap
  3→2, label opacity 0.7→0.75. Colors/text sizes/maxLines+ellipsis
  behavior unchanged from the previous pass. Added a test asserting the
  strip-to-card width ratio falls in 0.55–0.85 (a deliberately wide band
  around the requested "roughly 70–75%" — not pinning the exact private
  constant) and that the strip's center-x matches the card's center-x
  within 1px. 63 flashcards tests now (1 new), 0 failures. Full project
  suite: 152 tests, 0 failures; `flutter analyze` clean.

  **Answer text (`_back()`) enlarged to match the question text.** Was
  `AppTypography.subtitle.copyWith(fontWeight: w800)` (14px); now the same
  explicit style the front face's question text uses — `fontSize: 22,
  fontWeight: w900`, navy — for visual consistency between the two faces.
  Nothing else in `_back()` (ANSWER tag, spacing, source strip) touched.
  Added a test comparing the answer style directly against the live
  question style (not just checking it against a hardcoded 22/w900) so a
  future change to the front's style would be caught here too if the two
  drift apart again. 64 flashcards tests now (1 new), 0 failures. Full
  project suite: 153 tests, 0 failures; `flutter analyze` clean.

## Design handoffs

- `docs/mockups/android-study-app-redesign/` — Phase 0 (Auth: Welcome, Log
  In, Create Account, Forgot Password) is implemented. Phase 1 (Home &
  Courses) is in the same bundle: the Home frames are implemented. The
  Courses-tab frames are Manar's Courses & Material upload feature
  (`feature/courses`, see Feature split) — not yet built, and hers to scope.
- `docs/mockups/design_handoff_flashcard/` — the same design-system bundle,
  with the Phase 2b (Flashcards) frames and reference PNGs added. Used to
  build the Flashcards feature's screens (see Phase C above); not a
  pixel-precision pass like Phase B's.
