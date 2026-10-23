import 'package:flutter/material.dart';

/// The student's rank ladder: ten tiers earned purely by [totalPoints].
///
/// Thresholds, names and colours come from SRS Figures 109/110 and the
/// Profile design handoff's `TIERS` table, which agree exactly.
///
/// Lives in `lib/utils/` rather than inside the Profile feature so any
/// feature can derive a rank — Home, Quiz and Flashcards all have reason
/// to. The colours sit here too rather than in `AppColors`: they are rank
/// data, not theme roles, and `app_colors.dart` is a shared file frozen
/// after Phase B.
///
/// ---
///
/// **INTEGRATION POINT — `Student.currentRank` is not written anywhere yet.**
///
/// Every screen derives the rank from `totalPoints` through
/// [rankForPoints], so the displayed rank is always correct. The *stored*
/// `currentRank` field still holds whatever it was created with
/// (`'Beginner Learner'`) and will disagree with the displayed value.
///
/// To close that gap: wherever `totalPoints` is incremented, also set
/// `currentRank` to `rankForPoints(newTotal).name`. Today that is two
/// places, both in Ghaida's services —
/// `QuizSessionService` (`'totalPoints': FieldValue.increment(...)`, in
/// both the complete and retake-complete paths) and `FlashcardService`
/// (the same increment in its completion batch). Because
/// `FieldValue.increment` never reveals the resulting total, each call site
/// needs the new total read back (or computed from the known previous
/// value) before it can write the matching rank.
///
/// Deliberately not done here: those are another member's files, and the
/// change needs coordinating with her. See CLAUDE.md's Progress Log.
@immutable
class Rank {
  const Rank({
    required this.name,
    required this.minPoints,
    required this.maxPoints,
    required this.color,
    required this.tier,
  });

  /// Full rank name as the SRS writes it, e.g. "Beginner Learner".
  final String name;

  /// Lowest point total that earns this rank.
  final int minPoints;

  /// Highest point total still inside this rank, or null for the unbounded
  /// top rank.
  final int? maxPoints;

  /// The rank's identifying colour, from the design's `TIERS` table.
  final Color color;

  /// 1-based position in the ladder, so the UI can print "3 / 10".
  final int tier;

  /// The name without the trailing " Learner", for the Profile summary
  /// card where the full name doesn't fit — the design shows "Beginner"
  /// there and "Beginner Learner" on the progress card.
  String get shortName =>
      name.endsWith(' Learner') ? name.substring(0, name.length - 8) : name;

  /// True for the top rank, which has no ceiling and no next rank.
  bool get isTop => maxPoints == null;

  /// "0 – 99 pts", or "7,000+ pts" for the top rank.
  String get rangeLabel => isTop
      ? '${_thousands(minPoints)}+ pts'
      : '${_thousands(minPoints)} – ${_thousands(maxPoints!)} pts';
}

/// Groups digits with commas: 1450 -> "1,450". The design prints every
/// point total this way (`toLocaleString`).
String _thousands(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer(value < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// The ten ranks, lowest first. Contiguous: every rank's [Rank.minPoints]
/// is exactly one more than the previous rank's [Rank.maxPoints], so no
/// point total can fall between two ranks.
const List<Rank> kRanks = [
  Rank(
    name: 'Beginner Learner',
    minPoints: 0,
    maxPoints: 99,
    color: Color(0xFF9AA0C4),
    tier: 1,
  ),
  Rank(
    name: 'Active Learner',
    minPoints: 100,
    maxPoints: 299,
    color: Color(0xFF16A34A),
    tier: 2,
  ),
  Rank(
    name: 'Focused Learner',
    minPoints: 300,
    maxPoints: 699,
    color: Color(0xFF0EA5A5),
    tier: 3,
  ),
  Rank(
    name: 'Rising Learner',
    minPoints: 700,
    maxPoints: 1199,
    color: Color(0xFF2563EB),
    tier: 4,
  ),
  Rank(
    name: 'Skilled Learner',
    minPoints: 1200,
    maxPoints: 1799,
    color: Color(0xFF6D28D9),
    tier: 5,
  ),
  Rank(
    name: 'Advanced Learner',
    minPoints: 1800,
    maxPoints: 2599,
    color: Color(0xFFC026D3),
    tier: 6,
  ),
  Rank(
    name: 'Proficient Learner',
    minPoints: 2600,
    maxPoints: 3599,
    color: Color(0xFFF5A524),
    tier: 7,
  ),
  Rank(
    name: 'Expert Learner',
    minPoints: 3600,
    maxPoints: 4999,
    color: Color(0xFFEA580C),
    tier: 8,
  ),
  Rank(
    name: 'Elite Learner',
    minPoints: 5000,
    maxPoints: 6999,
    color: Color(0xFFE31B23),
    tier: 9,
  ),
  Rank(
    name: 'Master Learner',
    minPoints: 7000,
    maxPoints: null,
    color: Color(0xFF0B0F5B),
    tier: 10,
  ),
];

/// The rank [points] earns.
///
/// A null total (the student document hasn't loaded, or the field is
/// missing) and any negative total both resolve to the first rank rather
/// than throwing: a rank is decoration on a number, and a missing number
/// should render as "Beginner Learner", never as an error.
Rank rankForPoints(int? points) {
  final total = (points ?? 0) < 0 ? 0 : (points ?? 0);
  // Walk down so the unbounded top rank is matched by its minimum alone.
  for (var i = kRanks.length - 1; i >= 0; i--) {
    if (total >= kRanks[i].minPoints) return kRanks[i];
  }
  return kRanks.first;
}

/// The rank above [rank], or null when [rank] is already the top one.
Rank? nextRankAfter(Rank rank) {
  final index = kRanks.indexOf(rank);
  if (index < 0 || index >= kRanks.length - 1) return null;
  return kRanks[index + 1];
}

/// How many points [points] still needs to reach the next rank, or null at
/// the top rank where there is nothing left to reach.
///
/// Never negative: a total already past the next rank's threshold would
/// have resolved to that rank in the first place.
int? pointsToNextRank(int? points) {
  final total = (points ?? 0) < 0 ? 0 : (points ?? 0);
  final next = nextRankAfter(rankForPoints(total));
  if (next == null) return null;
  final remaining = next.minPoints - total;
  return remaining < 0 ? 0 : remaining;
}

/// How far [points] has travelled through its own rank, as 0.0–1.0.
///
/// The top rank has no span to measure, so it always reads as full — the
/// design fills its bar completely and labels it "top rank".
double progressWithinRank(int? points) {
  final total = (points ?? 0) < 0 ? 0 : (points ?? 0);
  final rank = rankForPoints(total);
  if (rank.isTop) return 1;
  final span = rank.maxPoints! - rank.minPoints;
  if (span <= 0) return 1;
  final through = (total - rank.minPoints) / span;
  return through.clamp(0.0, 1.0);
}

/// [points] formatted the way every Profile and Ranks label prints it.
String formatPoints(int? points) => _thousands((points ?? 0) < 0 ? 0 : points ?? 0);
