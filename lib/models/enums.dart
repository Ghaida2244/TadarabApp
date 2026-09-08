/// Quiz session mode: answer-then-submit vs. immediate per-question feedback.
enum Mode { exam, learning }

/// Difficulty requested when generating a quiz or flashcard set.
enum DifficultyLevel { easy, medium, hard }

/// Review state a flashcard is marked with after being flipped.
enum ReviewStatus { knowIt, needsReview }

/// Unit used for CalendarEvent.reminderBefore (e.g. "15 Minutes before").
enum ReminderUnit { minutes, hours, days, weeks }

extension ModeJson on Mode {
  String toJson() => name;
  static Mode fromJson(String value) => Mode.values.byName(value);
}

extension DifficultyLevelJson on DifficultyLevel {
  String toJson() => name;
  static DifficultyLevel fromJson(String value) =>
      DifficultyLevel.values.byName(value);
}

extension ReviewStatusJson on ReviewStatus {
  String toJson() => name;
  static ReviewStatus fromJson(String value) =>
      ReviewStatus.values.byName(value);
}

extension ReminderUnitJson on ReminderUnit {
  String toJson() => name;
  static ReminderUnit fromJson(String value) =>
      ReminderUnit.values.byName(value);
}
