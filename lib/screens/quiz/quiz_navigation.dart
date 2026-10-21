import 'package:flutter/widgets.dart';

/// Route name given to the pushed [QuizSessionsScreen] so deeper Quiz
/// screens' "Back to course" actions can return straight to it regardless
/// of how many screens are stacked above (Setup -> Play -> Summary ->
/// Review Mistakes) — see [popToQuizSessions].
const String quizSessionsRouteName = 'quiz-sessions';

/// Pops back to the Quiz sessions list. Falls back to popping to the first
/// route in the stack if no route is named [quizSessionsRouteName] — keeps
/// this safe to call from a screen pumped standalone in a widget test,
/// where there's no such named route beneath it.
void popToQuizSessions(BuildContext context) {
  Navigator.of(
    context,
  ).popUntil((route) => route.settings.name == quizSessionsRouteName || route.isFirst);
}

/// Drives [QuizSessionsScreen]'s reload-on-return.
///
/// NOT driven by chaining `.then()` off the `Navigator.push` that opened
/// Setup — that broke as soon as the flow ahead of it (Setup -> Play ->
/// Summary) started using `pushReplacement`: `pushReplacement` completes
/// the *replaced* route's own "popped" future immediately, at replacement
/// time, not when the student is actually done. That made the original
/// push's `.then(reload)` fire right after quiz generation (before any
/// question was answered), and nothing ever fired it again for the rest of
/// that quiz's lifecycle.
///
/// A [RouteObserver] doesn't have this problem — `didPopNext` fires from
/// the Navigator's actual route-visibility transitions, so it reliably
/// reflects "the student is genuinely back on this screen," no matter how
/// many `push`/`pushReplacement`/`popUntil` steps happened in between.
/// Registered on the app's [MaterialApp] in main.dart; a screen that wants
/// to reload on return subscribes to it with [RouteAware] (see
/// QuizSessionsScreen).
final RouteObserver<PageRoute<dynamic>> quizSessionsRouteObserver =
    RouteObserver<PageRoute<dynamic>>();
