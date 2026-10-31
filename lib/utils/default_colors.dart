/// The default course/event colour: green. The single source of truth for
/// that hex value — model classes fall back to this when a stored `color`
/// field is missing or empty, and [kCoursePresetColors]'s first entry and
/// Add Event's own `defaultEventColor`
/// (`lib/screens/calendar/calendar_styles.dart`) both reference this
/// constant too, so nothing quietly drifts apart.
///
/// Lives here (not in `lib/services/courses_service.dart`, where it used to
/// be defined) so model files (`Course`, `CalendarEvent`) can use it without
/// importing a service file that pulls in Firebase Auth/Storage — a plain
/// `lib/utils` file has no such dependency. Still re-exported from
/// `courses_service.dart` so existing imports of it from there keep
/// working.
const kDefaultCourseColor = '#16A34A';
