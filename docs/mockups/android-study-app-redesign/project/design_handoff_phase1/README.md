# Handoff: Tadarab — Phase 1 (Home & Courses)

## Overview
Redesign of the Tadarab Android study app: Home, Courses, course creation, material upload
(with AI read), and course detail. Playful/illustrated direction — rounded cards, chunky
"pressable" shadows, Nunito, brand red + deep blue.

## About the design files
`Tadarab Phase 1 - Home & Courses.dc.html` is a **design reference written in HTML**, not
production code. The app is **Flutter** — recreate these screens as Dart widgets using the
project's existing patterns (its theme, routing, state management and folder structure). Do not
port the HTML. Open the file in a browser to see the live states (marked "live" — upload,
delete, course picker, add course).

### Flutter notes
- Put the tokens below in the app's `ThemeData` / a `TadarabColors` class — no literal hex in widgets.
- The hard offset shadow is `BoxShadow(color: …, offset: Offset(0, 4), blurRadius: 0)` — blur must stay 0.
- The press effect is a 90ms `AnimatedContainer`/`AnimatedSlide` of 4px down with the shadow offset
  dropping to 1px — not `InkWell`'s default ripple.
- Bottom sheets are `showModalBottomSheet` with `isScrollControlled: true`, a 28px top radius and
  barrier `Color(0x800B0F5B)`.
- Nunito via `google_fonts`; weight 900 for headings/labels, 700–800 for body.
- The rainbow colour tile opens a colour picker package (e.g. `flutter_colorpicker`) — any colour allowed.
- Course colour is a field on the course model, not a theme value; the detail header, tile and events read it.

## Fidelity
**High-fidelity.** Colors, type, spacing and radii below are final; match them.

## Screens — name, purpose, and which state it represents
Every screen below is one *state* of a destination, not a separate destination. Implement each
destination once and drive it from data; the mock exists so the empty/filled/overflow cases are
unambiguous.

| ID | Screen (state) | Purpose — when the user sees it |
| --- | --- | --- |
| 1 | **Home — new student** (empty) | First run: no courses, no sessions. Explains the loop and pushes the single action "Add your first course". |
| 2 | **Home — session in progress** | Returning student who left a quiz/flashcard session unfinished: today's counts, streak strip, and a Resume card for that session. |
| 2b | **Home — nothing in progress** | Returning student with courses but no unfinished session. The Resume card is *replaced* by "Start a new session" → New quiz / Flashcards. Neither button assumes a course, so both open the **Choose a course** bottom sheet (course rows show what's ready: questions for quiz, cards for flashcards). |
| 3 | **Courses — empty** | Courses tab before any course exists. Single empty-state card → Add course. |
| 4 | **Courses — list** | Courses tab with courses. Each tile shows the course colour, initials, code and material count, with a red trash button per tile. Contains two overlays: **Add course** (name + colour picker) and **Delete course confirmation**. |
| 4a | **Add course** (overlay of 4) | Create a course: name field, colour row = 4 available presets + a rainbow tile that opens the OS colour picker (any colour), live preview tile. Colours already used by another course are locked/hidden. Shows the **duplicate name error** state. |
| 4b | **Delete confirmation** (overlay of 4) | Destructive confirm before removing a course and everything generated from it. |
| 5 | **Course detail** — few materials | The normal case (3 materials): Study tools (Quiz, Flashcards) + material list + Upload. Contains the **Upload material** sheet: file chosen → renameable name field → AI read progress → success ("Added to IS230 · +20 pts") → Generate from it. |
| 5b | **Course detail — many materials** (12) | Overflow case: tools and header collapse to a compact block, a type filter row (All / PPTX / DOCX / TXT) appears, and only the material list scrolls. Use this layout above ~6 materials. |
| 5c | **Course — no materials** | A course just created: header reads "No materials yet", Study tools are rendered but **disabled at 45% opacity** with the note "Upload a material to unlock quizzes and flashcards", and a dashed empty-state card drives "Upload material". |

### Navigation
Bottom bar (deep blue pill, 4 tabs with icons): Home · Courses · Calendar · Profile — a custom
widget inside a `Scaffold.bottomNavigationBar`, not a stock `BottomNavigationBar`.
Home 1/2/2b, Courses 3/4 are tab roots (`IndexedStack` or a shell route). 5/5b/5c are pushed
routes from a course tile and get a back arrow + trash in a header block filled with **that
course's colour**. Calendar and Profile are Phase 3.

## Key rules the mock encodes
- **Course colour is chosen at creation and inherited everywhere**: the tile, the detail header, and
  any event created for that course.
- **Streak strip**: one tile per weekday; the number is *questions + flashcards combined* that day.
  Today = white tile, future days = dashed outline. Streak = consecutive days with ≥1 session.
- **Study tools are locked until at least one material exists** (5c).
- Course tiles show only the material count; question/card counts appear in the course picker sheet.

## Interactions
- Press: `translateY(4px)` and the hard shadow shrinks to 1px (buttons/tiles). ~90ms ease.
- Bottom sheets: slide up 240ms `cubic-bezier(0.2,0.8,0.2,1)`, scrim `rgba(11,15,91,0.5)`, tap scrim to dismiss.
- New list items: pop-in 240ms.
- AI read: staged progress bar with status text, then a success row.

## Design tokens
Colors — red `#E31B23` (press `#A8141B`), deep blue `#0B0F5B` (press `#070A3E`), page `#F7F8FD`,
surface `#FFFFFF`, tint `#EEF0FF`, red tint `#FFE9EA`, border `#E2E6F5` / `#DDE1F0`,
body text `#0B0F5B`, secondary `#7A80A6`, muted `#9AA0C4`.
Course colours — green `#16A34A`, blue `#2563EB`, amber `#F5A524`, purple `#7C3AED`, + any picked colour.
Semantic — success `#16A34A` on `#E6F7EC`, warning `#8A5A06` on `#FFF3DC`.
Type — Nunito; 900 for all headings/labels, 700–800 for body/meta. 26px screen title,
19–22px card title, 15–17px body, 12–13px meta, 10–11px micro labels.
Radii — 999px pills, 28px sheets/headers, 20–26px cards, 12–16px small tiles.
Shadow — hard offset only, moderate depth: `0 3px 0` for buttons, tiles and cards; `0 5px 0` for the
large navy hero cards. Tint at 8–18% of the fill colour (or ~60% alpha of the darker brand shade on
solid buttons). No blur. Pressed state drops to `0 1px 0`.
Spacing — 20px screen padding, 10–18px gaps, 44–56px control heights (min 44px touch target).

## Icons
Stroked line icons, 2–2.2px, rounded caps: home, two-page book (Courses & Quiz), calendar,
person (Profile), stacked cards (Flashcards), trash, file-plus, search, chevron.

## Files
- `Tadarab Phase 1 - Home & Courses.dc.html` — all screens above
- `android-frame.jsx`, `support.js` — device frame + runtime for the mock
- `ref/` — the original app screenshots this redesign replaces
