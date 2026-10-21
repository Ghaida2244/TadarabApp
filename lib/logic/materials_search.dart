// Pure, Firestore-free logic for Course Detail's materials search + sort
// (lib/screens/courses/course_detail_screen.dart) — filtering, ordering,
// and title-highlight-span computation, all directly unit-testable. See
// docs/mockups/design-handoff_MaterialsShearch/ (variant 1a, "Filled
// pill") for the design this implements.

import '../models/study_material.dart';

/// How the materials list is ordered. [newestFirst] is the default.
enum MaterialSortOrder { newestFirst, oldestFirst, aToZ }

/// Materials whose title contains [query] as a case-insensitive substring
/// — surrounding whitespace in [query] is ignored. An empty/blank query
/// matches everything (returns [materials] unchanged, not filtered to
/// nothing).
List<StudyMaterial> filterMaterialsByQuery(
  List<StudyMaterial> materials,
  String query,
) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return materials;
  return materials.where((m) => m.title.toLowerCase().contains(q)).toList();
}

/// Sorts [materials] per [order]. Never mutates the input.
///
/// - [MaterialSortOrder.newestFirst] / [MaterialSortOrder.oldestFirst]:
///   ordered by [StudyMaterial.createdAt]. A material with no stored
///   `createdAt` (an old document that predates this field) sorts *after*
///   every dated one in newestFirst, and *before* all of them in
///   oldestFirst — never interleaved by the dated ones. Ties (including
///   two materials both missing `createdAt`) are broken by title, via the
///   same natural comparator [aToZ] uses.
/// - [MaterialSortOrder.aToZ]: title ascending, case-insensitive, natural
///   order (so "Lecture 2" sorts before "Lecture 10" — see
///   [_compareTitlesNatural]).
List<StudyMaterial> sortMaterials(
  List<StudyMaterial> materials,
  MaterialSortOrder order,
) {
  final sorted = List<StudyMaterial>.from(materials);
  switch (order) {
    case MaterialSortOrder.newestFirst:
      sorted.sort(_compareNewestFirst);
    case MaterialSortOrder.oldestFirst:
      sorted.sort(_compareOldestFirst);
    case MaterialSortOrder.aToZ:
      sorted.sort((a, b) => _compareTitlesNatural(a.title, b.title));
  }
  return sorted;
}

int _compareNewestFirst(StudyMaterial a, StudyMaterial b) {
  final ca = a.createdAt;
  final cb = b.createdAt;
  if (ca == null && cb == null) {
    return _compareTitlesNatural(a.title, b.title);
  }
  if (ca == null) return 1; // a (undated) goes after b (dated).
  if (cb == null) return -1; // b (undated) goes after a (dated).
  final cmp = cb.compareTo(ca); // descending: most recent first.
  return cmp != 0 ? cmp : _compareTitlesNatural(a.title, b.title);
}

int _compareOldestFirst(StudyMaterial a, StudyMaterial b) {
  final ca = a.createdAt;
  final cb = b.createdAt;
  if (ca == null && cb == null) {
    return _compareTitlesNatural(a.title, b.title);
  }
  if (ca == null) return -1; // a (undated) goes before b (dated).
  if (cb == null) return 1; // b (undated) goes before a (dated).
  final cmp = ca.compareTo(cb); // ascending: oldest first.
  return cmp != 0 ? cmp : _compareTitlesNatural(a.title, b.title);
}

final _chunkPattern = RegExp(r'\d+|\D+');

bool _isDigitChunk(String chunk) {
  final firstUnit = chunk.codeUnitAt(0);
  return firstUnit >= 0x30 && firstUnit <= 0x39;
}

/// Case-insensitive, natural-order title comparison: splits each title
/// into alternating digit/non-digit runs and compares digit runs
/// numerically (see [_compareDigitRuns]) rather than character-by-character
/// — "Lecture 2" sorts before "Lecture 10", not after.
int _compareTitlesNatural(String a, String b) {
  final chunksA = _chunkPattern.allMatches(a.toLowerCase())
      .map((m) => m.group(0)!)
      .toList();
  final chunksB = _chunkPattern.allMatches(b.toLowerCase())
      .map((m) => m.group(0)!)
      .toList();
  final len = chunksA.length < chunksB.length ? chunksA.length : chunksB.length;
  for (var i = 0; i < len; i++) {
    final chunkA = chunksA[i];
    final chunkB = chunksB[i];
    final cmp = _isDigitChunk(chunkA) && _isDigitChunk(chunkB)
        ? _compareDigitRuns(chunkA, chunkB)
        : chunkA.compareTo(chunkB);
    if (cmp != 0) return cmp;
  }
  return chunksA.length.compareTo(chunksB.length);
}

/// Compares two runs of ASCII digits *numerically*, without ever parsing
/// them into an [int] (a run can be arbitrarily long — e.g. a pasted ID —
/// and `int.parse` would overflow or throw well before that). Strips
/// leading zeros first (so "007" and "7" compare equal), then compares by
/// length (a longer digit run is always numerically larger once leading
/// zeros are gone), then lexicographically (same length means the usual
/// character-by-character ASCII digit comparison already matches numeric
/// order).
int _compareDigitRuns(String a, String b) {
  final sa = _stripLeadingZeros(a);
  final sb = _stripLeadingZeros(b);
  if (sa.length != sb.length) return sa.length.compareTo(sb.length);
  return sa.compareTo(sb);
}

String _stripLeadingZeros(String digits) {
  var i = 0;
  // Stops one short of the end so an all-zero run ("000") reduces to a
  // single "0" instead of the empty string.
  while (i < digits.length - 1 && digits.codeUnitAt(i) == 0x30) {
    i++;
  }
  return digits.substring(i);
}

/// The three pieces a material row's title splits into around a search
/// match: the part before it, the matched text itself (to be highlighted),
/// and the part after. `null` when [query] is blank, doesn't match, or
/// (see below) can't be matched safely.
typedef MaterialTitleHighlight = ({String before, String match, String after});

/// Finds [query] inside [title], case-insensitively, for highlighting.
///
/// Matching is done on lowercased copies, but the returned pieces are
/// sliced from the *original* [title] (so the match keeps its real
/// casing) using the indices found in the lowercased search. That's only
/// safe when lowercasing doesn't change either string's length. In other
/// language runtimes (e.g. JavaScript/ICU full case folding), some
/// Unicode characters expand when lowercased — e.g. Turkish "İ" → "i" plus
/// a combining mark — which would shift every index after them and
/// silently highlight the wrong substring. Dart's `String.toLowerCase`
/// only uses Unicode's *simple* (always length-preserving) case mappings
/// — confirmed by scanning every codepoint in the BMP and SMP, none change
/// length — so this branch can't currently be triggered by any input. The
/// guard is kept anyway as a defensive backstop against that changing
/// (a different Dart/Flutter string implementation, a future SDK version,
/// a locale-aware override) rather than trusting it stays true forever:
/// if either string's length changes under [String.toLowerCase], this
/// returns `null` (render the plain title) rather than risk a misaligned
/// highlight.
MaterialTitleHighlight? highlightMatch(String title, String query) {
  final trimmedQuery = query.trim();
  if (trimmedQuery.isEmpty) return null;

  final lowerTitle = title.toLowerCase();
  final lowerQuery = trimmedQuery.toLowerCase();
  if (lowerTitle.length != title.length ||
      lowerQuery.length != trimmedQuery.length) {
    return null;
  }

  final index = lowerTitle.indexOf(lowerQuery);
  if (index < 0) return null;

  return (
    before: title.substring(0, index),
    match: title.substring(index, index + trimmedQuery.length),
    after: title.substring(index + trimmedQuery.length),
  );
}
