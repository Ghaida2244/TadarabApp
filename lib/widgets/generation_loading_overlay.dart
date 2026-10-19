import 'dart:async';

import 'package:flutter/material.dart';

import '../models/enums.dart';

/// Builds the fixed line shown under a [GenerationLoadingOverlay]'s
/// rotating messages — "Aiming for {count} {noun} · {difficulties}" — in
/// one place, so Quiz and Flashcards can't drift apart on its format
/// again; each caller passes only [count], [noun] (e.g. "questions" or
/// "flashcards") and its own selected [difficulties].
///
/// [difficulties] always renders in the fixed easy/medium/hard order (via
/// [DifficultyLevel.values], not whatever order the caller's own set
/// happens to iterate in), lowercase, joined with ", " — e.g. "easy",
/// "easy, medium", "easy, medium, hard". [noun] is passed in exactly as
/// the caller wants it rendered (already pluralized) since the real
/// minimum selectable count is 5 — a count of 1 can't currently occur,
/// but is rendered without crashing (just without a singular/plural
/// distinction, which this helper has no way to apply to an opaque noun
/// string).
String buildGenerationFixedLine({
  required int count,
  required String noun,
  required Set<DifficultyLevel> difficulties,
}) {
  final orderedDifficulties = DifficultyLevel.values
      .where(difficulties.contains)
      .map((d) => d.name)
      .join(', ');
  return 'Aiming for $count $noun · $orderedDifficulties';
}

/// The wording one [GenerationLoadingOverlay] rotates through. Kept
/// separate from the overlay itself so the same screen can be reused for a
/// future Retake flow with different wording — see NOTE 8 — without
/// touching the overlay's own timer/fade logic.
class GenerationLoadingConfig {
  const GenerationLoadingConfig({
    required this.sentence,
    required this.tip,
    required this.longWaitMessage,
  });

  /// The main rotating line, e.g. "Preparing your quiz...".
  final String sentence;

  /// The rotating line alternated with [sentence], e.g. a study tip.
  final String tip;

  /// Replaces the sentence/tip rotation once [GenerationLoadingOverlay]'s
  /// `longWaitThreshold` elapses, and stays — the rotation never resumes.
  final String longWaitMessage;
}

/// The full-screen, light-navy overlay shown while a quiz or flashcard set
/// is being generated. [sentence] and [tip] (from [config]) alternate with
/// a fade every [rotationInterval]; after [longWaitThreshold] the rotation
/// is replaced by [GenerationLoadingConfig.longWaitMessage] for good, in
/// case generation is taking unusually long. [fixedLine] (e.g. "Aiming for
/// 10 questions · easy") sits below the rotating text and never changes.
///
/// Both timers are cancelled in [dispose] — removing this widget from the
/// tree (e.g. because generation finished or failed) stops them for good,
/// so neither fires `setState` after disposal.
class GenerationLoadingOverlay extends StatefulWidget {
  const GenerationLoadingOverlay({
    super.key,
    required this.config,
    required this.fixedLine,
    this.rotationInterval = const Duration(seconds: 5),
    this.longWaitThreshold = const Duration(seconds: 45),
  });

  final GenerationLoadingConfig config;
  final String fixedLine;

  /// How often the sentence/tip rotation flips. Exposed so tests can drive
  /// it with a short, controlled duration instead of waiting on 45 real
  /// seconds of wall-clock time.
  final Duration rotationInterval;

  /// How long the rotation runs before being replaced by
  /// [GenerationLoadingConfig.longWaitMessage] for good. Exposed for the
  /// same testability reason as [rotationInterval].
  final Duration longWaitThreshold;

  @override
  State<GenerationLoadingOverlay> createState() =>
      _GenerationLoadingOverlayState();
}

class _GenerationLoadingOverlayState extends State<GenerationLoadingOverlay> {
  bool _showingTip = false;
  bool _longWait = false;
  Timer? _rotationTimer;
  Timer? _longWaitTimer;

  // A plain sentence/tip toggle only has two possible keys, so alternating
  // between them repeats a key while its *previous* occurrence may still
  // be mid-fade-out in AnimatedSwitcher — a documented AnimatedSwitcher
  // pitfall where reusing a key for an incoming child clashes with that
  // same key's still-animating outgoing child. Counting every rotation
  // instead gives each transition a genuinely unique key.
  int _tick = 0;

  @override
  void initState() {
    super.initState();
    _rotationTimer = Timer.periodic(widget.rotationInterval, (_) {
      if (!mounted) return;
      setState(() {
        _showingTip = !_showingTip;
        _tick++;
      });
    });
    _longWaitTimer = Timer(widget.longWaitThreshold, () {
      if (!mounted) return;
      // The long-wait message replaces the rotation for good — stop the
      // rotation timer too, rather than let it keep ticking uselessly.
      _rotationTimer?.cancel();
      setState(() {
        _longWait = true;
        _tick++;
      });
    });
  }

  @override
  void dispose() {
    _rotationTimer?.cancel();
    _longWaitTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final message = _longWait
        ? widget.config.longWaitMessage
        : (_showingTip ? widget.config.tip : widget.config.sentence);

    return Positioned.fill(
      child: Container(
        color: const Color(0xE60B0F5B),
        padding: const EdgeInsets.all(34),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 46,
              height: 46,
              child: CircularProgressIndicator(
                strokeWidth: 5,
                valueColor: AlwaysStoppedAnimation(Colors.white),
              ),
            ),
            const SizedBox(height: 18),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: Text(
                message,
                key: ValueKey(_tick),
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 13),
            Text(
              widget.fixedLine,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Color(0xB3FFFFFF),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
