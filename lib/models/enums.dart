enum Mode { exam, learning }// The available quiz modes
enum DifficultyLevel { easy, medium, hard }// The available difficulty levels
enum ReviewStatus { knowIt, needsReview }// The review options for a flashcard
enum ReminderUnit { minutes, hours, days, weeks }// The available units for reminders

// Converts the quiz mode to text for saving and back to enum when reading
extension ModeJson on Mode {
  String toJson() => name;
  static Mode fromJson(String value) => Mode.values.byName(value);
}

// Converts difficulty levels between enum values and text
extension DifficultyLevelJson on DifficultyLevel {
  String toJson() => name;
  static DifficultyLevel fromJson(String value) =>
      DifficultyLevel.values.byName(value);
}
// Converts review statuses between enum values and text
extension ReviewStatusJson on ReviewStatus {
  String toJson() => name;
  static ReviewStatus fromJson(String value) =>
      ReviewStatus.values.byName(value);
}
// Converts reminder units between enum values and text
extension ReminderUnitJson on ReminderUnit {
  String toJson() => name;
  static ReminderUnit fromJson(String value) =>
      ReminderUnit.values.byName(value);
}
