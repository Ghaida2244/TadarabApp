# Courses & Material Upload — Feature Spec (Phase C)

**Owner:** Manar — branch `feature/courses`
**Read this alongside `CLAUDE.md` at the project root.** This document is the
full, agreed-upon spec for this feature. It has been discussed and confirmed
in detail — implement exactly what's written here. If anything is still
ambiguous once you're building, stop and ask rather than guessing.

---

## 0. Scope

This feature is a standalone Phase C vertical: Courses (create/list/delete)
and their Study Materials (upload/list/view). It is **not** shared team work —
it does not overlap with Home, Auth, or any other feature. The only touch
outside this feature's own files is a single-line routing change (see
Section 9).

**Design reference:** the mockups live at
`docs/mockups/design_handoff_phase1/`. This folder holds **all** of Phase 1's
frames, including Home's (already built in Phase B) and other unrelated
ones — only the Courses-numbered frames (course list, add course, course
detail, upload material, delete confirmation) are relevant here. Use them for
visual reference (colors, spacing, copy, icons), but **this written spec is
the source of truth wherever it's more specific than or differs from what
the mockup images show** — every rule in this document reflects a decision
made directly with the team after the mockups were drawn (e.g. no delete
button on the courses list, the exact color-lock behavior, the simplified
upload-success flow). If something in the mockups isn't covered here, ask
before assuming.

---

## 1. Screens & states

Build these screens, matching the attached mockups:

1. **Courses — empty state**: icon, "No courses yet", subtitle, "Add your
   first course" CTA, `+` button in header.
2. **Courses — list state**: header shows "N courses"; each row shows the
   course's colored initials icon, name, and material count — **no delete
   control on this screen**. Tapping a row opens Course Detail.
3. **Add Course** (opened by the `+` button or the empty-state CTA): course
   name field, 5 preset color swatches + a custom color-picker tile, a live
   preview card, and a Save button. See Section 2 for validation rules.
4. **Course Detail — no materials**: Study Tools (Quiz, Flashcards) shown
   **locked/disabled** with the message "Upload a material to unlock quizzes
   and flashcards."; materials section shows an empty state with "Add your
   first material" / "Upload material" CTA.
5. **Course Detail — has materials**: Study Tools **enabled**; materials
   section shows an "+ Upload" button, type filter tabs (All / PPTX / DOCX /
   TXT, each with a count), and the material list.
6. **Upload Material** (bottom sheet, opened from Course Detail): see
   Section 4 for the full flow.
7. **Delete course confirmation** (dialog, opened from the trash icon in
   Course Detail's header only): see Section 3.

---

## 2. Add Course — validation logic

- **Name**: required (non-empty). Must be **unique among this student's own
  courses**, comparison is **case-sensitive** (`IS230` and `is230` are
  different and both allowed).
- **Color**: 5 preset swatches + one custom color-picker tile (full color
  wheel/RGB input). A preset swatch is **locked** (visibly disabled, not
  selectable) if it's already the color of another of this student's
  existing courses. The custom picker is never locked. When a course using a
  given color is deleted, that color becomes available again immediately.
- **Save button** is disabled until both a valid, unique name **and** a color
  are set. Live preview (icon + name + "0 materials") updates as the user
  types/picks.
- **Course icon initials**: always the **first two characters of the course
  name, taken literally** — not the first letter of each word. E.g. "Data
  Structures" → `DA`, not `DS`. Handle names shorter than 2 characters
  gracefully.
- On duplicate name: keep Save disabled and show an inline warning under the
  name field (e.g. "You already have a course named this").

---

## 3. Delete course

- Delete is only reachable from **inside Course Detail** (trash icon in the
  colored header). There is no delete control on the Courses list screen.
- Tapping it opens a confirmation dialog:
  - Title: `Delete [course name]?`
  - Body: "Deleting this course will also delete all its materials, quizzes,
    and flashcard sessions. This can't be undone."
  - Buttons: **Delete course** (destructive/primary) and **Keep it**
    (cancel, dismisses with no change).
- On confirm: cascade-delete the course document, all its materials
  subcollection documents, their files in Storage, and any quiz/flashcard
  session documents that reference this course (once those collections
  exist — for now, just the course + materials + Storage files).
- **Also cascade-delete this course's calendar events.** `CalendarEvent` has
  a nullable `courseID` field (per CLAUDE.md's data model) — when a course
  is deleted, query `users/{uid}/events` for documents where `courseID`
  matches this course, and delete them too. This is Leen's data
  (Calendar & Points/Ranks & Profile feature), but the deletion trigger
  lives entirely in this feature's code, so it's this feature's
  responsibility to make the call.
  **Confirmed with Leen:** her `feature/calendar-points` branch isn't merged
  yet, so write the direct Firestore query/delete yourself for now. Leen is
  independently adding a function with the exact same name and signature,
  `deleteEventsForCourse(uid, courseId)`, on her own branch (inside her
  `CalendarService`), doing the same deletion. Once her branch merges,
  replace this feature's inline query with a single call to
  `CalendarService.deleteEventsForCourse(uid, courseId)` — the logic itself
  won't need to be rewritten, just the call site.
- The course's color is freed for reuse immediately after deletion.

---

## 4. Upload Material — full flow

Bottom sheet, opened via the "+ Upload" button or the empty-state CTA in
Course Detail:

1. Dashed drop-zone: "Choose a file" — accepts PPTX / DOCX / TXT only. See
   Section 8 for the size limit (currently an open item).
2. Once a file is chosen, a name field is shown, **pre-filled with the
   file's name** (extension may be stripped). The student can freely edit
   this to anything they want — no length or character restrictions — but it
   cannot be empty.
3. **Name uniqueness**: must be unique **within this course only** (the same
   name is fine in a different course), comparison is **case-sensitive**. On
   duplicate: keep the Upload button disabled and show an inline warning.
4. Tapping **Upload** runs, in order:
   a. Show an "Uploading the file..." state (with an "AI" badge and a
      progress indicator) while the raw file uploads to Firebase Storage
      under the existing `users/{uid}/...` path convention.
   b. Extract text from the file (see Section 5). **If extraction yields no
      readable text at all, reject the upload**: do not save the material,
      do not show a success state — show a clear error such as "This file
      has no readable text" instead, and let the student pick a different
      file.
   c. On successful extraction, write the new `StudyMaterial` document (see
      Section 6 for its fields) to Firestore.
   d. Replace the sheet's content with "Added successfully to [course
      name]" — no buttons.
   e. After ~2 seconds, auto-dismiss the sheet with no tap required, and
      return to Course Detail with the updated materials list (and Study
      Tools now unlocked, if this was the course's first material).

---

## 5. Text extraction — how and where

Extraction runs **client-side, in Flutter/Dart** (not the Cloudflare Worker —
that was considered and rejected in favor of keeping this feature
self-contained; revisit only if the packages below prove unreliable).

Suggested starting point — **test both on a handful of real files (with
headings, tables, and images) before committing to them**:
- `open_xml` (pub.dev) for PPTX (and DOCX if it proves reliable there too).
- `doc_text_extractor` (pub.dev) for DOCX, since its "chapter splitting"
  feature is the closest fit for detecting headings.

If neither library reliably extracts slide/heading structure on real files,
stop and report back rather than shipping something that silently produces
wrong `sourceLocation`s.

---

## 6. `StudyMaterial` model — new field

Add `extractedText` (String) to `StudyMaterial`. Final field set:

```
materialID, title, type, document, courseID, extractedText
```

This is a **deviation from the original Attributes Dictionary Table** (a new
field, not previously documented) — log it explicitly in CLAUDE.md's
Progress Log / model-deviation list, the same way `document` being a Storage
path (not a BLOB) was already logged. Report this deviation before writing
the model class, don't fix it silently.

---

## 7. `extractedText` format — **exact contract with the AI generation
feature, do not deviate**

This format was agreed directly with Ghaida (owner of quiz/flashcard
generation) since her generation prompt parses these exact labels. Rules:

- **Do not include the material's name/title anywhere inside
  `extractedText`.** The generation Worker wraps the text with a
  `[Material: Title]` label itself, at generation time, using the existing
  `title` field on `StudyMaterial` — adding it here would duplicate it.
- **PPTX** — for every slide, emit a line `[Slide N: <slide title>]`
  followed by that slide's text content:
  ```
  [Slide 1: Introduction to Data Mining]
  Chapter 1 — Introduction to Data Mining, IS 463.
  [Slide 2: Chapter Outline]
  Topics covered: Why Data Mining, What Is Data Mining, ...
  ```
- **DOCX** — for every section led by a heading, emit `[Heading N: <heading
  text>]` followed by that section's content:
  ```
  [Heading 1: Functional Requirements]
  Functional requirements describe what the system should do...
  ```
  Any content with **no** heading above it (an intro before the first
  heading, or a document with no headings at all) uses `[Paragraph N]`
  **with nothing inside the brackets but the word and number** — no title:
  ```
  [Paragraph 1]
  This document covers the fundamentals of requirements engineering.
  ```
- **TXT** — every paragraph uses `[Paragraph N]` the same way (no title
  inside the brackets), since there's no natural slide/heading structure.
- `N` is a running number specific to each tag type, matching the source
  file's real order.

---

## 8. Open item — confirm before finalizing

**File size limit is unresolved.** `CLAUDE.md`'s non-functional requirements
say materials up to 10MB; the design mockup's Upload screen copy says "up to
20 MB." These conflict. **Default to 10MB** (the currently documented,
team-agreed number) for both the client-side check and the UI copy, but
flag this conflict explicitly rather than silently picking either number —
the person running this session will confirm with the team and update both
places together once resolved.

---

## 9. Navigation & the one shared-file touch

- Full flow: Courses tab → list (empty or populated) → `+` → Add Course →
  Save → back to list (new course visible) → tap a course → Course Detail →
  `+ Upload` → bottom sheet → auto-dismiss → back to Course Detail (updated).
- Tapping either Study Tools tile (Quiz or Flashcards) when unlocked
  navigates to the existing shared `PlaceholderScreen` — a single generic
  placeholder regardless of which tile was tapped. Ghaida and Deemah will
  wire in their real screens later; don't build a picker or anything fancier
  here.
- The bottom nav's "Courses" tab is currently wired to `PlaceholderScreen()`
  inside the shared routing file (frozen since Phase B merged, per
  CLAUDE.md's Git workflow rules). **The only change allowed there** is
  swapping that one line for the real Courses entry screen — nothing else in
  that file. Make this specific change in its own commit, clearly labeled
  (e.g. "Routing: wire Courses tab to real Courses feature"), since it
  touches shared/frozen code and needs full-team PR review, not just one
  approval.

---

## 10. Testing (per CLAUDE.md's standing requirements)

- **Unit tests**, each covering a normal case, an edge case, and a failure
  case: course-name uniqueness check, material-name uniqueness check
  (scoped per-course), color-lock logic (including a color freeing up after
  its course is deleted), course-initials generation, and the
  empty-extracted-text validation.
- **Widget tests**, one per state shown in the design: courses empty,
  courses list, Add Course (including the duplicate-name and
  no-color-selected disabled states), Course Detail locked, Course Detail
  unlocked, every Upload Material state (idle, uploading, success,
  empty-file error, duplicate-name error), and the delete confirmation
  dialog.
- Run `flutter test` and report the actual pass/fail counts — not just
  "tests pass."

---

## 11. Before writing any code

Per CLAUDE.md's standing rule: present a short plan (what it covers, what
it'll look/behave like, any open questions) and wait for confirmation before
writing code.
