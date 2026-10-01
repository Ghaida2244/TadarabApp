# Tadarab — design handoff (Phases 0–2)

Redesign of the Tadarab study app: auth, home, courses, materials and the whole quiz flow.
Playful/illustrated direction — rounded cards, chunky "pressable" shadows, Nunito, brand red +
deep blue.

## About the design files
These are **design references written in HTML**, not production code. The app is **Flutter** —
recreate these screens as Dart widgets using the project's existing patterns (its theme, routing,
state management, folder structure). Do not port the HTML.

| File | What's in it |
| --- | --- |
| `Tadarab Phase 0 - Auth.dc.html` | Welcome, Log in, Create Account, Forgot Password + every validation/error/loading state (13 frames) |
| `Tadarab Phase 1 - Home & Courses.dc.html` | Home (3 states), Courses (empty/list), Add course, Upload material, Course detail (3 states) |
| `Tadarab Phase 2 - Quiz.dc.html` | **A working interactive prototype** of the quiz flow — open it and tap through it |
| `Tadarab Phase 2b - Flashcards.dc.html` | **A working interactive prototype** of the flashcard flow — sessions, setup, flip deck, review pass, summary |

Phase 2 is deliberately interactive: the states are produced by real logic rather than drawn, so
the button rules, disabled states, loading and the session semantics below are demonstrable. Open
it in a browser and use it before writing code.

### Flutter notes
- Put the tokens below in `ThemeData` / a `TadarabColors` class — no literal hex in widgets.
- The hard offset shadow is `BoxShadow(color: …, offset: Offset(0, 3), blurRadius: 0)` — blur stays 0.
- The press effect is a ~90ms 2–4px downward shift with the shadow offset dropping to 1px — not `InkWell`'s ripple.
- Bottom sheets: `showModalBottomSheet`, `isScrollControlled: true`, 28px top radius, barrier `Color(0x800B0F5B)`.
- Nunito via `google_fonts`; weight 900 for headings/labels, 700–800 for body.
- The rainbow colour tile opens a colour picker package (e.g. `flutter_colorpicker`) — any colour allowed.
- Course colour is a field on the course model, not a theme value; tiles, detail headers and events read it.
- Custom bottom nav widget inside `Scaffold.bottomNavigationBar`, not a stock `BottomNavigationBar`.

---

## Phase 0 — Auth

| ID | Screen (state) | When the user sees it |
| --- | --- | --- |
| A1 | **Welcome** | First launch, signed out. Logo, tagline, Log In / Create Account. |
| A2 | **Log in** | Default empty form. |
| A2b | **Log in — empty fields** | Submitted with nothing filled: both fields in error, "Email is required" / "Password is required". |
| A2c | **Log in — invalid email** | Live format check on blur; password field untouched/valid. |
| A2d | **Log in — wrong credentials** | Server rejected the pair: banner "Email or password is incorrect" + attempts remaining. Never say which field was wrong. |
| A2e | **Log in — signing in** | Request in flight: fields locked at 50%, button becomes a spinner "Signing in…", links inert. |
| A3 | **Create Account** | Default form: name, email, password, re-enter. |
| A3b | **Create Account — validation** | Invalid email + weak password (strength meter at 1/3) + "Passwords don't match", all inline. |
| A3c | **Create Account — email taken** | Duplicate account banner with two routes: "Log in instead" / "Reset password". |
| A3d | **Create Account — creating** | Request in flight, same loading treatment as A2e. |
| A4 | **Forgot Password** | Email field + "Send reset link"; note that the link expires in 30 minutes. |
| A4b | **Forgot Password — valid email typed** | Green border purely from **live format validation**, before any request. |
| A4c | **Forgot Password — link sent** | Confirmation: "If an account exists, a reset link was sent to…" — the same reply whether or not the account exists (no account-existence leak), with a resend countdown. |

Rules: validation is inline and specific, never a generic toast; the reset flow must not reveal
whether an email is registered; loading states disable their form.

---

## Phase 1 — Home, Courses, Materials

| ID | Screen (state) | When the user sees it |
| --- | --- | --- |
| 1 | **Home — new student** (empty) | First run: no courses, no sessions. One action: "Add your first course". |
| 2 | **Home — session in progress** | Returning student with an unfinished session: today's counts, streak strip, Resume card. |
| 2b | **Home — nothing in progress** | Courses but no unfinished session: Resume card is *replaced* by "Start a new session" → New quiz / Flashcards. Neither button assumes a course — both open the **Choose a course** sheet (rows show what's ready: questions for quiz, cards for flashcards). |
| 3 | **Courses — empty** | Courses tab before any course exists. |
| 4 | **Courses — list** | Course tiles (colour, initials, code, material count) + per-tile red trash. Holds two overlays: Add course, Delete confirmation. |
| 4a | **Add course** (overlay) | Name + colour row = 4 available presets + rainbow tile opening the OS picker (any colour); live preview tile; colours used by another course are locked. Includes the duplicate-name error. |
| 4b | **Delete course confirmation** | Destructive confirm before removing a course and everything generated from it. |
| 5 | **Course detail — few materials** | Normal case (3): Study tools (Quiz, Flashcards) + material list + Upload. Holds the **Upload material** sheet: file chosen → renameable name field → AI read progress → success → Generate from it. |
| 5b | **Course detail — many materials** (12) | Overflow case: header/tools collapse, type filter row (All / PPTX / DOCX / TXT), only the list scrolls. Use above ~6 materials. |
| 5c | **Course — no materials** | Freshly created course: "No materials yet", Study tools rendered but **disabled at 45% opacity** with "Upload a material to unlock quizzes and flashcards", dashed empty state → Upload material. |

Rules: course colour is chosen at creation and inherited everywhere (tile, detail header, its
events); the streak strip counts **questions + flashcards combined** per day, today white, future
days dashed, streak = consecutive days with ≥1 session; study tools stay locked until a material
exists; tiles show only the material count (question/card counts live in the course picker).

---

## Phase 2 — Quiz flow

Screens, each with its states: **Quiz sessions** (empty / in progress / completed), **Quiz setup**
(+ questions-limit dialog, + generating), **Quiz — Exam Mode**, **Quiz — Learning Mode** (before
answer / after answer), **Performance summary** (per mode), **Review mistakes** (collapsed /
expanded), plus the **delete-session** and **save-and-leave** dialogs.

### Quiz sessions
- Rows show **mode** (Exam / Learning), a status dot with **In progress** / **Completed**, the
  question count and — when finished — the correct count. **No percentage, no material name.**
- In progress → "Resume at question N". Completed → "View performance summary" with **Retake quiz**
  directly beneath it.
- Delete goes through a confirmation dialog ending in "This can't be undone."
- Empty state appears whenever the list is empty.

### Quiz setup
- **Materials** is a collapsed control ("Select materials ▾") that expands to a checkbox list for
  multi-select and collapses back to a summary ("3 materials selected").
- **Difficulty is multi-select** — Easy + Hard together is valid; at least one must stay selected.
- The count is a **target, not a promise**: label it "Questions to aim for" and never state a
  guaranteed number before generation.
- Custom instructions with quick chips: "Include an example with each question", "Focus on
  definitions", "Add real-world scenarios".
- Generate shows a full-screen reading state, then — if the AI produced fewer questions than asked
  — the limit dialog ("Start with these" / "Change the setup") *before* the first question.

### Quiz — Exam Mode
- **Fully locked.** No back button, no close/X, no exit sheet, and the system back must not leave.
  A "LOCKED" chip in the header states this. The only way out is submitting.
- Pip-style progress (one pip per question: current red, answered white, unanswered faint) — not a bar.
- Buttons are **stacked vertically: Next on top, Previous beneath it**. Next is disabled (pink fill)
  until an answer is selected for the current question; Previous is always enabled except on
  question 1. On the last question Next becomes **Submit quiz**.

### Quiz — Learning Mode
- Same pip progress. One question at a time: Submit is disabled until a pick.
- After submitting, **correct/incorrect is shown on the answer options themselves** — the correct
  option turns green and is marked CORRECT, the student's wrong pick turns red and is marked YOURS.
  No separate verdict banner.
- Below that: the explanation panel, with the **source as a navy footer strip** on the same card
  ("Find it in your material · Lecture 1 · Slide 8").
- Button becomes Next question, or **Finish quiz** on the last one.
- The X opens the **save-and-leave** sheet (see session semantics below).

### Performance summary
- **No percentage anywhere.**
- Fixed order: **correct/wrong counts → motivational message → points earned** → weak topics → actions.
- Points = 4 per correct answer, and they feed the home streak counts.
- Actions by mode: Exam → **Review mistakes** + Back to course; Learning → **Practice the weak ones**
  + Back to course. **No Retake here** — retake lives on Quiz sessions.
- Review mistakes is Exam Mode only, and only when something was wrong.

### Review mistakes
Accordion per wrong answer: question, your answer (red), and on expand the correct answer (green),
the explanation and the source. "Show the answer" / "Hide details" per card; Back to course at the bottom.

---

## Phase 2b — Flashcards (`Tadarab Phase 2b - Flashcards.dc.html`)

Also a **working interactive prototype**. Screens: **Flashcard sessions** (empty / in progress /
completed), **Flashcard setup** (+ limit dialog, + generating), the **flip deck**, the **review
pass**, and **Performance summary** — plus the delete-session and save-and-leave dialogs.

**There is no mode selector.** Flashcards have one mode; nothing in this flow splits Exam / Learning.

### Flashcard sessions
Same anatomy as Quiz sessions: grouped **IN PROGRESS** above **COMPLETED**, mode chip reads DECK,
status dot + label, no percentage and no material name. In progress → "Resume at card N";
completed → "View performance summary" with **Retake flashcards** beneath it. Delete goes through
the same "This can't be undone" confirmation.

### Flashcard setup
Collapsible multi-select materials control, **multi-select difficulty**, "Cards to aim for" (a
target, not a promise), custom instructions with the same 300-character live counter and
amber/red warning states, and the three quick chips. **Generate is disabled (pink fill) with a
stated reason when no material is selected.** Then the reading state, then the limit dialog if the
material yielded fewer cards than asked.

### The flip deck
- Pip progress per card: current red, known green, marked-for-review white, untouched faint.
- The card itself is the control — tapping it flips question ⇄ answer. Front: QUESTION tag, the
  question, its example, and a "Tap to flip" affordance. Back: ANSWER tag, the answer, and the
  source in a tinted strip on the same card.
- **"Need review" and "I know it" are rendered only once the card is flipped** — they do not exist
  on the front face. Each records the mark and advances; on the last card it goes to the summary.
- The X opens the save-and-leave sheet (real sessions only — see session semantics).

### Review pass ("Review now")
Opens only the cards marked for review, answer-side up, navigated with **Next on top / Previous
beneath** (Previous disabled on the first card, Next becomes "Done reviewing" on the last). No
verdict buttons — nothing is re-marked. This is a **practice session**: untracked, no save prompt,
exiting always discards it.

### Performance summary
Same system as Quiz: **counts → motivational message → points earned** → marked-for-review topics
→ actions. Counts are **I know it** / **Need review**; **points = 2 per known card**; the message
reuses the quiz tiers (trophy ≥80%, star ≥50%, arrow below) with matching tint. No percentage.
Actions: **Review now** (only when something was marked), **Retake flashcards**, **Back to course**.

### ⚠ Session semantics — implement exactly

These rules are identical for quiz sessions and flashcard sessions — a flashcard session stores its
per-card marks where a quiz session stores its answers.

**Real sessions (created from setup or resumed from the list):**
- A session has a stable id. Resuming a session **updates that same session** — its answers, its
  answered count and its resume position. It must **never create a second session**, and the
  progress already stored must **never be silently dropped**.
- Leaving via the X saves the current answers into that same session and returns to the list, where
  it still reads "In progress" with the new count and resumes at the question the student was on.
- Finishing a resumed session marks **that** session completed and attaches its result, rather than
  prepending a new completed row.
- Retake on a completed session restarts the same session id from question 1 with a cleared result.

**Practice sessions ("Practice the weak ones" after a Learning summary, and "Review now" after a flashcard summary):**
- Never tracked and never saved. They do **not** appear in Quiz sessions.
- The X must **not** show the save-and-leave sheet — tapping it exits immediately. Showing a "save
  your progress" prompt here would be a lie.
- Exiting always discards progress; entering practice again starts from the beginning.

The prototype in `Tadarab Phase 2 - Quiz.dc.html` implements all of the above — test against it.

---

## Design tokens
Colors — red `#E31B23` (press `#A8141B`), deep blue `#0B0F5B` (press `#070A3E`), page `#FFFFFF`,
surface `#FFFFFF`, tint `#EEF0FF`, red tint `#FFE9EA`, border `#E2E6F5` / `#DDE1F0`,
body text `#0B0F5B`, secondary `#7A80A6`, muted `#9AA0C4`, disabled-red fill `#F3A8AC`.
Course colours — green `#16A34A`, blue `#2563EB`, amber `#F5A524`, purple `#7C3AED`, + any picked colour.
Semantic — success `#16A34A` on `#E6F7EC` / `#F4FCF7`, warning `#8A5A06` on `#FFF3DC`,
error `#C31018` / `#8F0C13` on `#FFE9EA` / `#FFF7F7`.
Type — Nunito; 900 for headings/labels, 700–800 for body/meta. 26–28px screen title,
19–22px card title, 15–17px body, 12–13px meta, 10–11px micro labels.
Radii — 999px pills, 28–30px sheets/headers, 16–26px cards, 11–16px small tiles. Nothing square.
Page vs card separation — the page is **pure white**, so a white card must never sit on it
unseparated. Every white card carries a 2px `#EEF0FF` ring plus its hard offset shadow
(`box-shadow: 0 0 0 2px #EEF0FF, 0 3px 0 rgba(11,15,91,0.08)`; in Flutter: a `#EEF0FF` border on
the card decoration alongside the offset shadow). Inner panels inside a card use `#F7F8FD` /
`#EEF0FF` fills instead of white. Inputs keep their `#E2E6F5` border.

Shadow — hard offset only, moderate depth: `0 3px 0` for buttons, tiles and cards; `0 5px 0` for
the large navy hero cards; tint at 8–18% of the fill (or ~60% alpha of the darker brand shade on
solid buttons). No blur. Pressed drops to `0 1px 0`.
Spacing — 20–22px screen padding, 10–18px gaps, 44–56px control heights (min 44px touch target).

## Interactions
- Press: 2–4px down, hard shadow shrinks to 1px, ~90ms ease.
- Bottom sheets: slide up 240ms `cubic-bezier(0.2,0.8,0.2,1)`, scrim `rgba(11,15,91,0.5)`, tap scrim to dismiss.
- New list items and revealed feedback: pop-in ~220ms, same curve.
- Disabled buttons stay visible — pink fill for a red action, grey outline for a secondary one. Never hide them.
- AI read / auth requests: staged progress or spinner with status text, form disabled meanwhile.

## Icons
Stroked line icons, 2–2.2px, rounded caps: home, two-page book (Courses & Quiz), calendar, person,
stacked cards (Flashcards), trash, file-plus, mail, lock, eye, check, cross, clock, chevrons.

## Files in this bundle
- The three `.dc.html` design files above
- `android-frame.jsx`, `support.js` — device frame + runtime the mocks need
- `tadarab-logo.png` — the navy/red logo used on the auth screens
- `ref/` — the original app screenshots this redesign replaces

## Still to design (Phase 3)
Calendar + add event, profile / ranks / edit profile, study reminders + notifications,
legal pages.
