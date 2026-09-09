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

**Team members** *(fill in before Phase C — see "Feature split" below):*
- Member A: ____________
- Member B: ____________
- Member C: ____________
- Member D: ____________

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

## Feature split (fill in once the team decides)

| Member | Feature | Branch |
|---|---|---|
| ______ | Courses & Material upload | `feature/courses` |
| ______ | Quiz generation & Sessions | `feature/quiz-sessions` |
| ______ | Flashcards & Sessions | `feature/flashcards` |
| ______ | Calendar & Points/Ranks & Profile | `feature/calendar-points` |

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
  compiles cleanly. Not yet deployed — needs the Anthropic API key (not
  obtained yet) and an interactive `wrangler login` from a team member; see
  `worker/README.md`.
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
  Remaining for Phase B: the Home & Courses screens (a separate design
  handoff, not yet started).
- **Phase C — Feature split:** not started

## Design handoffs

- `docs/mockups/android-study-app-redesign/` — Phase 0 (Auth: Welcome, Log
  In, Create Account, Forgot Password) is implemented. Phase 1 (Home &
  Courses) is in the same bundle but not yet built.
