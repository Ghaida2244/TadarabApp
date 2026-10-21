import 'package:flutter/widgets.dart';

/// Route name given to the pushed [FlashcardSessionsScreen] so deeper
/// Flashcards screens' "Back to sessions" actions can return straight to
/// it regardless of how many screens are stacked above (Setup -> Flip
/// Deck -> Performance Summary) — mirrors Quiz's own
/// `quizSessionsRouteName`/`popToQuizSessions` (see
/// `lib/screens/quiz/quiz_navigation.dart`).
const String flashcardSessionsRouteName = 'flashcard-sessions';

/// Pops back to the Flashcard sessions list. Falls back to popping to the
/// first route in the stack if no route is named
/// [flashcardSessionsRouteName] — keeps this safe to call from a screen
/// pumped standalone in a widget test, or reached via a path that doesn't
/// go through the Sessions list (e.g. Resume from Home), where there's no
/// such named route beneath it.
void popToFlashcardSessions(BuildContext context) {
  Navigator.of(context).popUntil(
    (route) =>
        route.settings.name == flashcardSessionsRouteName || route.isFirst,
  );
}
