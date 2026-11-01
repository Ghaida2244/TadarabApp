import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/enums.dart';
import '../../../models/study_material.dart';
import '../../../services/flashcard_service.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/keyboard_safe_padding.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_error_banner.dart';
import '../../../widgets/dismiss_keyboard_on_tap.dart';
import '../../../widgets/generation_loading_overlay.dart';
import '../widgets/header_circle_button.dart';
import '../widgets/limit_dialog.dart';
import 'flashcard_flip_deck_screen.dart';

/// NOTE 8's wording for the Flashcards setup's generating overlay. Retake's
/// own wording isn't implemented yet (a later task) — this config only
/// covers a fresh generation.
const kFlashcardLoadingConfig = GenerationLoadingConfig(
  sentence: 'Preparing your flashcards...',
  tip: 'Say the answer out loud before you flip the card.',
  longWaitMessage:
      "Thanks for your patience. We're still putting it together.",
);

/// Retake's own wording for the Flashcards generating overlay — same tip
/// and long-wait message as a fresh generation, just a different opening
/// line (see flashcard_sessions_screen.dart's `_retake`).
const kFlashcardRetakeLoadingConfig = GenerationLoadingConfig(
  sentence: 'Creating new flashcards for you...',
  tip: 'Say the answer out loud before you flip the card.',
  longWaitMessage:
      "Thanks for your patience. We're still putting it together.",
);

const _kMinCount = 5;
const _kMaxCount = 150;
const _kDefaultCount = 10;
const _kCustomPromptMaxLength = 300;
const _kPromptChips = [
  'Include an example with each flashcard',
  'Focus on definitions',
  'Add real-world scenarios',
];

/// Colors from `Tadarab Phase 2b - Flashcards.dc.html`'s setup screen, not
/// in `AppColors` (Flashcards-only, avoids touching the shared frozen theme
/// file).
const _kEyebrowInk = Color(0xFF9AA0C4);
const _kEyebrowFaint = Color(0xFFC9CEE8);
const _kFieldTint = Color(0xFFF4F6FF);
const _kMutedInk = Color(0xFF5B618F);
const _kAmber = Color(0xFFF5A524);
// README's own documented "disabled-red fill" token, used for the Generate
// button's disabled-but-not-loading state (see _Footer below).
const _kDisabledRedFill = Color(0xFFF3A8AC);

/// Screen 2: pick materials, difficulty, count and an optional custom
/// prompt, then generate a flashcard deck.
class FlashcardSetupScreen extends StatefulWidget {
  const FlashcardSetupScreen({
    super.key,
    required this.uid,
    required this.courseId,
    required this.email,
    this.service,
  });

  final String uid;
  final String courseId;
  final String email;

  /// Overridable for tests; defaults to the real Firebase-backed service.
  final FlashcardService? service;

  @override
  State<FlashcardSetupScreen> createState() => _FlashcardSetupScreenState();
}

class _FlashcardSetupScreenState extends State<FlashcardSetupScreen> {
  late final FlashcardService _service =
      widget.service ??
      FlashcardService(uid: widget.uid, courseId: widget.courseId);

  late final Future<List<StudyMaterial>> _materialsFuture = _service
      .fetchMaterials();

  final Set<String> _selectedMaterialIds = {};
  // Easy is selected by default (NOTE 13a, matching Quiz setup) so a
  // first-time user isn't blocked purely on difficulty. Matches Quiz
  // setup's own selection rule exactly: any level can be freely added or
  // removed, except the *last* remaining selected one — at least one
  // level is always selected, never fully empty (see the onChanged
  // callback below).
  final Set<DifficultyLevel> _selectedDifficulties = {DifficultyLevel.easy};
  int _count = _kDefaultCount;
  final _promptController = TextEditingController();

  // Defaults open (unlike the design handoff's collapsed-by-default
  // control) so the materials list stays immediately reachable — matches
  // the existing widget tests, which select a material without first
  // opening the panel.
  bool _materialsOpen = true;

  bool _generating = false;
  String? _errorMessage;

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  bool get _canGenerate =>
      _selectedMaterialIds.isNotEmpty &&
      _selectedDifficulties.isNotEmpty &&
      _count > 0 &&
      !_generating;

  Future<void> _generate(List<StudyMaterial> materials) async {
    setState(() {
      _generating = true;
      _errorMessage = null;
    });

    try {
      final result = await _service.generateFlashcards(
        materialIds: _selectedMaterialIds.toList(),
        difficulties: _selectedDifficulties.toList(),
        count: _count,
        customPrompt: _promptController.text.trim().isEmpty
            ? null
            : _promptController.text.trim(),
      );

      if (!mounted) return;
      setState(() => _generating = false);

      if (result.note != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.note!)),
        );
      }

      if (result.items.length == _count) {
        await _startSession(materials, result.items, result.coveredTopics);
      } else {
        await showFewerCardsDialog(
          context,
          actualCount: result.items.length,
          requestedCount: _count,
          onStartWithActual: () =>
              _startSession(materials, result.items, result.coveredTopics),
          onChangeSetup: () {},
        );
      }
    } on WorkerUnreachableException {
      if (!mounted) return;
      setState(() {
        _generating = false;
        _errorMessage = kFlashcardNetworkFailureMessage;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _generating = false;
        _errorMessage = kFlashcardGenericFailureMessage;
      });
    }
  }

  Future<void> _startSession(
    List<StudyMaterial> materials,
    List<FlashcardGenerationItem> items,
    List<String> coveredTopics,
  ) async {
    final selected = materials
        .where((m) => _selectedMaterialIds.contains(m.materialId))
        .toList();
    try {
      final sessionId = await _service.createSession(
        email: widget.email,
        materialIds: selected.map((m) => m.materialId).toList(),
        materialTitles: selected.map((m) => m.title).toList(),
        difficultyLevels: _selectedDifficulties.toList(),
        customPrompt: _promptController.text.trim().isEmpty
            ? null
            : _promptController.text.trim(),
        items: items,
        coveredTopics: coveredTopics,
      );
      final flashcards = await _service.fetchFlashcards(sessionId);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => FlashcardFlipDeckScreen(
            uid: widget.uid,
            courseId: widget.courseId,
            sessionId: sessionId,
            initialFlashcards: flashcards,
            initialIndex: 0,
            initialKnownCount: 0,
            initialNeedsReviewCount: 0,
            service: _service,
          ),
        ),
      );
    } on FlashcardFailure catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    }
  }

  String _materialsSummary(List<StudyMaterial> materials) {
    if (_selectedMaterialIds.isEmpty) return 'Select materials';
    if (_selectedMaterialIds.length == 1) {
      final material = materials.firstWhere(
        (m) => m.materialId == _selectedMaterialIds.first,
        orElse: () => materials.first,
      );
      return material.title;
    }
    return '${_selectedMaterialIds.length} materials selected';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      // The Generate flashcards footer below (_Footer) is pinned outside
      // the scroll area, at the bottom of the Column — without this,
      // opening the keyboard (e.g. typing the card count or extra
      // instructions) shrinks the Scaffold's body and drags that footer
      // up above it instead of letting the keyboard simply cover it. See
      // keyboardSafePadding below for the matching fix on the scroll
      // view's own padding.
      resizeToAvoidBottomInset: false,
      body: FutureBuilder<List<StudyMaterial>>(
        future: _materialsFuture,
        builder: (context, snapshot) {
          final materials = snapshot.data ?? const <StudyMaterial>[];
          return DismissKeyboardOnTap(
            child: Stack(
            children: [
              Column(
                children: [
                  _Header(onBack: () => Navigator.of(context).maybePop()),
                  Expanded(
                    child: SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: keyboardSafePadding(
                        context,
                        const EdgeInsets.fromLTRB(22, 18, 22, 16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_errorMessage != null) ...[
                            AppErrorBanner(
                              heading: 'Could not generate flashcards',
                              body: _errorMessage!,
                            ),
                            const SizedBox(height: AppSpacing.lg),
                          ],
                          const _EyebrowLabel('MATERIALS'),
                          const SizedBox(height: 9),
                          _MaterialsPicker(
                            materials: materials,
                            selected: _selectedMaterialIds,
                            open: _materialsOpen,
                            summary: _materialsSummary(materials),
                            onToggle: () =>
                                setState(() => _materialsOpen = !_materialsOpen),
                            onChanged: (id, value) => setState(() {
                              value
                                  ? _selectedMaterialIds.add(id)
                                  : _selectedMaterialIds.remove(id);
                            }),
                          ),
                          const SizedBox(height: 22),
                          const _EyebrowLabel('DIFFICULTY', suffix: ' · PICK ANY'),
                          const SizedBox(height: 9),
                          _DifficultyPicker(
                            selected: _selectedDifficulties,
                            onChanged: (level, value) => setState(() {
                              if (value) {
                                _selectedDifficulties.add(level);
                              } else if (_selectedDifficulties.length > 1) {
                                // Same rule as Quiz setup: never let the
                                // last remaining selected level be removed.
                                _selectedDifficulties.remove(level);
                              }
                            }),
                          ),
                          const SizedBox(height: 22),
                          const _EyebrowLabel('CARDS TO AIM FOR'),
                          const SizedBox(height: 9),
                          _CountStepper(
                            count: _count,
                            onChanged: (value) => setState(() => _count = value),
                          ),
                          const SizedBox(height: 22),
                          const _EyebrowLabel('EXTRA INSTRUCTIONS', suffix: ' · OPTIONAL'),
                          const SizedBox(height: 9),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final chip in _kPromptChips)
                                _PromptChip(
                                  label: chip,
                                  onTap: () => setState(() {
                                    _promptController.text = chip.length > 300
                                        ? chip.substring(0, 300)
                                        : chip;
                                  }),
                                ),
                            ],
                          ),
                          const SizedBox(height: 9),
                          _PromptField(
                            controller: _promptController,
                            onChanged: () => setState(() {}),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _Footer(
                    canGenerate: _canGenerate,
                    onGenerate: () => _generate(materials),
                  ),
                ],
              ),
              if (_generating)
                GenerationLoadingOverlay(
                  config: kFlashcardLoadingConfig,
                  fixedLine: buildGenerationFixedLine(
                    count: _count,
                    noun: 'flashcards',
                    difficulties: _selectedDifficulties,
                  ),
                ),
            ],
            ),
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
      decoration: const BoxDecoration(
        color: AppColors.red,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            HeaderCircleButton(icon: Icons.arrow_back_ios_new, onTap: onBack),
            const SizedBox(width: 13),
            // Expanded + maxLines/ellipsis: on a narrow screen the title
            // would otherwise force the Row wider than the screen itself
            // (a plain Text reports its full single-line width to a Row
            // with no flex to shrink it into) — ellipsis is the standard
            // header-title treatment rather than letting it wrap to a
            // second line. No visible change on a wide-enough screen,
            // where the title already fits on one line.
            Expanded(
              child: Text(
                'Flashcard setup',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EyebrowLabel extends StatelessWidget {
  const _EyebrowLabel(this.label, {this.suffix});

  final String label;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontFamily: 'Nunito',
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.06 * 12,
          color: _kEyebrowInk,
        ),
        children: [
          TextSpan(text: label),
          if (suffix != null) TextSpan(text: suffix, style: const TextStyle(color: _kEyebrowFaint)),
        ],
      ),
    );
  }
}

class _MaterialsPicker extends StatelessWidget {
  const _MaterialsPicker({
    required this.materials,
    required this.selected,
    required this.open,
    required this.summary,
    required this.onToggle,
    required this.onChanged,
  });

  final List<StudyMaterial> materials;
  final Set<String> selected;
  final bool open;
  final String summary;
  final VoidCallback onToggle;
  final void Function(String id, bool value) onChanged;

  @override
  Widget build(BuildContext context) {
    final noMats = selected.isEmpty;
    final edgeColor = open ? AppColors.navy : (noMats ? AppColors.red : AppColors.borderLight);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: onToggle,
          child: Container(
            height: 54,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: edgeColor, width: 2),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.cardTint,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(Icons.menu_book_outlined, size: 17, color: AppColors.navy),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    summary,
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: noMats ? AppColors.placeholder : AppColors.navy,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: open ? 0.5 : 0,
                  duration: const Duration(milliseconds: 160),
                  child: const Icon(Icons.expand_more, size: 20, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
        if (open) ...[
          const SizedBox(height: 8),
          if (materials.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('No materials in this course yet.', style: AppTypography.subtitle),
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.cardTint, width: 2),
                boxShadow: [
                  BoxShadow(color: AppColors.navy.withValues(alpha: 0.06), offset: const Offset(0, 3)),
                ],
              ),
              child: Column(
                children: [
                  for (final material in materials) ...[
                    _MaterialRow(
                      material: material,
                      selected: selected.contains(material.materialId),
                      onChanged: (value) => onChanged(material.materialId, value),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ],
    );
  }
}

class _MaterialRow extends StatelessWidget {
  const _MaterialRow({
    required this.material,
    required this.selected,
    required this.onChanged,
  });

  final StudyMaterial material;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: ValueKey('material-${material.materialId}'),
      onTap: () => onChanged(!selected),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? _kFieldTint : Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppColors.navy : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: selected ? AppColors.navy : AppColors.borderLight, width: 2),
              ),
              child: selected
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                material.title,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  height: 1.3,
                  color: AppColors.navy,
                ),
              ),
            ),
            Text(
              material.type.toUpperCase(),
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: _kEyebrowInk,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DifficultyPicker extends StatelessWidget {
  const _DifficultyPicker({required this.selected, required this.onChanged});

  final Set<DifficultyLevel> selected;
  final void Function(DifficultyLevel level, bool value) onChanged;

  static const _labels = {
    DifficultyLevel.easy: 'Easy',
    DifficultyLevel.medium: 'Medium',
    DifficultyLevel.hard: 'Hard',
  };

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final level in DifficultyLevel.values) ...[
          if (level != DifficultyLevel.values.first) const SizedBox(width: 8),
          Expanded(
            child: _DifficultyButton(
              key: ValueKey('difficulty-${level.name}'),
              label: _labels[level]!,
              on: selected.contains(level),
              onTap: () => onChanged(level, !selected.contains(level)),
            ),
          ),
        ],
      ],
    );
  }
}

class _DifficultyButton extends StatelessWidget {
  const _DifficultyButton({super.key, required this.label, required this.on, required this.onTap});

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Exactly matches Quiz setup's difficulty button (quiz_setup_screen.
    // dart's _buildDifficultySection) — same height/radius/border, the
    // same AppTypography.quizOption label style, and the same muted
    // (AppColors.disabledMuted) unselected text color, per the "Quiz is
    // the reference" rule. Only the selected button gets a shadow — see
    // its own comment below for why these exact values must stay in sync
    // with Quiz's.
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? AppColors.navy : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: on ? AppColors.navy : AppColors.borderDefault, width: 2),
          // A subtle soft shadow on the selected button only — unselected
          // stays flat with just its border. KEEP THESE EXACT VALUES IN
          // SYNC with quiz_setup_screen.dart's _buildDifficultySection
          // (same selected-button shadow, both screens).
          boxShadow: on
              ? [
                  BoxShadow(
                    color: AppColors.navy.withValues(alpha: 0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: AppTypography.quizOption(
            FontWeight.w900,
            color: on ? Colors.white : AppColors.disabledMuted,
          ),
        ),
      ),
    );
  }
}

class _CountStepper extends StatefulWidget {
  const _CountStepper({required this.count, required this.onChanged});

  final int count;
  final ValueChanged<int> onChanged;

  @override
  State<_CountStepper> createState() => _CountStepperState();
}

class _CountStepperState extends State<_CountStepper> {
  late final TextEditingController _controller = TextEditingController(
    text: '${widget.count}',
  );
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant _CountStepper oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only resync from outside (the +/- buttons) while the field isn't
    // being actively edited, so mid-typing text is never clobbered.
    if (widget.count != oldWidget.count && !_focusNode.hasFocus) {
      _controller.text = '${widget.count}';
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) _commit();
  }

  // Invalid or empty input reverts to the last valid count; a valid number
  // is clamped to the same [_kMinCount, _kMaxCount] range as the +/- buttons.
  void _commit() {
    final parsed = int.tryParse(_controller.text);
    final next = parsed == null
        ? widget.count
        : parsed.clamp(_kMinCount, _kMaxCount);
    _controller.text = '$next';
    if (next != widget.count) widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final atMin = widget.count <= _kMinCount;
    final atMax = widget.count >= _kMaxCount;

    return Row(
      children: [
        _StepCircle(
          valueKey: const ValueKey('count-decrement'),
          symbol: '−',
          enabled: !atMin,
          onTap: () => widget.onChanged(widget.count - 1),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: TextField(
            key: const ValueKey('count-field'),
            controller: _controller,
            focusNode: _focusNode,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onSubmitted: (_) => _focusNode.unfocus(),
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 30,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.zero,
              border: InputBorder.none,
            ),
          ),
        ),
        const SizedBox(width: 14),
        _StepCircle(
          valueKey: const ValueKey('count-increment'),
          symbol: '+',
          enabled: !atMax,
          onTap: () => widget.onChanged(widget.count + 1),
        ),
      ],
    );
  }
}

class _StepCircle extends StatelessWidget {
  const _StepCircle({required this.valueKey, required this.symbol, required this.enabled, required this.onTap});

  final Key valueKey;
  final String symbol;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: valueKey,
      onTap: enabled ? onTap : null,
      child: Container(
        width: 46,
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled ? AppColors.navy : AppColors.cardTint,
          shape: BoxShape.circle,
        ),
        child: Text(
          symbol,
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 26,
            fontWeight: FontWeight.w900,
            height: 1,
            color: enabled ? Colors.white : _kEyebrowFaint,
          ),
        ),
      ),
    );
  }
}

class _PromptChip extends StatelessWidget {
  const _PromptChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: AppColors.borderDefault, width: 2),
        ),
        child: Text(
          label,
          style: const TextStyle(fontFamily: 'Nunito', fontSize: 12, fontWeight: FontWeight.w900, color: _kMutedInk),
        ),
      ),
    );
  }
}

class _PromptField extends StatelessWidget {
  const _PromptField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final len = controller.text.length;
        final atLimit = len >= _kCustomPromptMaxLength;
        final approaching = len >= 260;
        final edgeColor = atLimit ? AppColors.red : (approaching ? _kAmber : AppColors.borderLight);
        final hintColor = atLimit ? AppColors.errorText : AppColors.warningText;
        final countColor = atLimit ? AppColors.errorText : (approaching ? AppColors.warningText : _kEyebrowInk);
        final hint = atLimit
            ? 'Character limit reached'
            : (approaching ? 'Approaching the limit' : '');

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: controller,
              maxLength: _kCustomPromptMaxLength,
              maxLines: 3,
              // Done, not the multiline default of a literal newline key —
              // a multiline field is otherwise the one control on this
              // screen with no way to close the keyboard from the
              // keyboard itself. The field still looks and wraps exactly
              // the same (same maxLines); only the IME's enter key stops
              // inserting a line break and submits/closes the keyboard
              // instead, same as a normal single-line field's enter key
              // already does.
              textInputAction: TextInputAction.done,
              buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
              onChanged: (_) => onChanged(),
              style: const TextStyle(fontFamily: 'Nunito', fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.navy, height: 1.5),
              decoration: InputDecoration(
                hintText: 'e.g. include an example with each flashcard',
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: edgeColor, width: 2)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: edgeColor, width: 2)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.navy, width: 2)),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(hint, style: TextStyle(fontFamily: 'Nunito', fontSize: 11, fontWeight: FontWeight.w800, color: hintColor)),
                Text('$len/$_kCustomPromptMaxLength', style: TextStyle(fontFamily: 'Nunito', fontSize: 11, fontWeight: FontWeight.w900, color: countColor)),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.canGenerate, required this.onGenerate});

  final bool canGenerate;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        boxShadow: [BoxShadow(color: AppColors.navy.withValues(alpha: 0.05), offset: const Offset(0, -3))],
      ),
      child: AppButton(
        label: 'Generate flashcards',
        variant: AppButtonVariant.accent,
        height: 56,
        borderRadius: 18,
        shadowColor: canGenerate ? AppColors.redShadow.withValues(alpha: 0.6) : Colors.transparent,
        disabledBackgroundColor: _kDisabledRedFill,
        onPressed: canGenerate ? onGenerate : null,
      ),
    );
  }
}

