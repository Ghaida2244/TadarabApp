/// The three Performance Summary message tiers — shared by Quiz and
/// Flashcards (NOTE 6) so both features show identical text and
/// thresholds, rather than each maintaining its own copy that can drift.
enum PerformanceTier { excellent, nice, needsWork }

/// Picks the tier from the exact ratio `numerator`/`denominator` — the
/// percentage is never displayed anywhere, only used internally to choose
/// which message to show. Compares the exact ratio directly (never rounds
/// first): `>= 0.80` is [PerformanceTier.excellent], `[0.50, 0.80)` is
/// [PerformanceTier.nice], and anything below that — including
/// `denominator == 0`, which can't happen for a real session (both
/// features' minimum counts are well above zero) but is guarded against
/// rather than dividing by zero — falls back to the lowest tier,
/// [PerformanceTier.needsWork].
PerformanceTier performanceTierFor({
  required int numerator,
  required int denominator,
}) {
  assert(numerator >= 0, 'numerator cannot be negative');
  assert(denominator >= 0, 'denominator cannot be negative');
  if (denominator == 0) return PerformanceTier.needsWork;
  final ratio = numerator / denominator;
  if (ratio >= 0.80) return PerformanceTier.excellent;
  if (ratio >= 0.50) return PerformanceTier.nice;
  return PerformanceTier.needsWork;
}

/// The exact motivational text for [tier] — identical wording for both the
/// Quiz and Flashcards performance summary screens.
String performanceTierMessage(PerformanceTier tier) {
  switch (tier) {
    case PerformanceTier.excellent:
      return 'Excellent work! You nailed it. You should be proud of this one.';
    case PerformanceTier.nice:
      return "Nice progress! You're close, keep it up.";
    case PerformanceTier.needsWork:
      return "This one needs more work before it clicks. You'll get there.";
  }
}
