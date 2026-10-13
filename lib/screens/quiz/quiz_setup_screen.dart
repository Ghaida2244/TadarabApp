import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/enums.dart';
import '../../models/study_material.dart';
import '../../services/quiz_generation_client.dart' show GenerationFailure;
import '../../services/quiz_session_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/generation_loading_overlay.dart';
import 'quiz_play_screen.dart';
import 'widgets/quiz_icon_button.dart';

/// NOTE 8's wording for the Quiz setup's generating overlay. Retake's own
/// wording isn't implemented yet (a later task) — this config only covers
/// a fresh generation.
const kQuizLoadingConfig = GenerationLoadingConfig(
  sentence: 'Preparing your quiz...',
  tip: 'Try to answer before you look at the options.',
  longWaitMessage:
      "Thanks for your patience. We're still putting it together.",
);

/// Retake's own wording for the Quiz generating overlay — same tip and
/// long-wait message as a fresh generation, just a different opening line
/// (see quiz_sessions_screen.dart's `_retake`).
const kQuizRetakeLoadingConfig = GenerationLoadingConfig(
  sentence: 'Creating new questions for you...',
  tip: 'Try to answer before you look at the options.',
  longWaitMessage:
      "Thanks for your patience. We're still putting it together.",
);

/// Materials (multi-select), difficulty (multi-select), question-count
/// stepper (min 5, no cap, +/- and direct numeric entry), mode, and an
/// optional 300-character extra-instructions field — then Generate.
class QuizSetupScreen extends StatefulWidget {
  const QuizSetupScreen({
    super.key,
    required this.courseId,
    required this.courseName,
    required this.service,
  });

  final String courseId;
  final String courseName;
  final QuizSessionService service;

  @override
  State<QuizSetupScreen> createState() => _QuizSetupScreenState();
}

const int _minQuestionCount = 5;
const int _maxQuestionCount = 150;
const int _defaultQuestionCount = 10;
const List<String> _promptChips = [
  'Include an example with each question',
  'Focus on definitions',
  'Add real-world scenarios',
];

class _QuizSetupScreenState extends State<QuizSetupScreen> {
  late Future<List<StudyMaterial>> _materialsFuture;
  final Set<String> _selectedMaterialIds = {};
  // Open by default, matching the Flashcards setup screen — the materials
  // list is immediately reachable rather than needing an extra tap.
  bool _materialsOpen = true;
  // Easy is selected by default on both setup screens (NOTE 13a); still
  // freely changeable/deselectable like any other chip.
  final Set<DifficultyLevel> _selectedDifficulties = {DifficultyLevel.easy};
  int _count = _defaultQuestionCount;
  Mode _mode = Mode.exam;
  final _promptController = TextEditingController();
  bool _generating = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _materialsFuture = widget.service.fetchMaterials(widget.courseId);
    _promptController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _generate(List<StudyMaterial> allMaterials) async {
    final materials = allMaterials
        .where((m) => _selectedMaterialIds.contains(m.materialId))
        .toList();
    if (materials.isEmpty || _selectedDifficulties.isEmpty) return;

    setState(() {
      _generating = true;
      _errorMessage = null;
    });

    try {
      final result = await widget.service.createSession(
        courseId: widget.courseId,
        materials: materials,
        difficulties: _selectedDifficulties.toList(),
        count: _count,
        mode: _mode,
        customPrompt: _promptController.text.trim().isEmpty
            ? null
            : _promptController.text.trim(),
      );
      if (!mounted) return;
      setState(() => _generating = false);

      // Same single decision gate for both modes, no per-mode branching:
      // createSession never writes anything (see its doc comment), so a
      // decline right here leaves zero trace in Firestore either way —
      // there's simply nothing yet to clean up.
      if (result.gotFewerThanRequested) {
        final startAnyway = await _showLimitDialog(
          actual: result.session.numberOfQuestions,
          requested: result.requestedCount,
        );
        if (!mounted || startAnyway != true) return;
      }
      if (!mounted) return;

      if (result.session.mode == Mode.learning) {
        // The one and only write for a Learning session's creation —
        // deliberately held until right here, after the decision above
        // is final, so a decline never leaves an orphaned session behind.
        await widget.service.commitLearningSession(
          session: result.session,
          questions: result.questions,
        );
      }
      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          // Exam mode never gets a persisted session at all here — see
          // QuizSessionService.submitExamSession — so it plays from an
          // in-memory draft instead of a Firestore-backed id. Learning
          // mode was just committed above, immediately before this.
          builder: (_) => result.session.mode == Mode.exam
              ? QuizPlayScreen.examDraft(
                  session: result.session,
                  questions: result.questions,
                  service: widget.service,
                )
              : QuizPlayScreen(
                  sessionId: result.session.sessionId,
                  service: widget.service,
                ),
        ),
      );
    } on NoQuestionsGeneratedException catch (e) {
      if (!mounted) return;
      setState(() {
        _generating = false;
        _errorMessage = e.note ??
            "Your material couldn't support any questions. Try adding another material.";
      });
    } on GenerationFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _generating = false;
        _errorMessage = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _generating = false;
        _errorMessage = 'Something went wrong. Please try again.';
      });
    }
  }

  Future<bool?> _showLimitDialog({required int actual, required int requested}) {
    return showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.warningBackground,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: const Icon(Icons.warning_amber_rounded, color: AppColors.warningText),
              ),
              const SizedBox(height: 13),
              Text('Fewer questions than asked', style: AppTypography.quizDialogTitle, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                'Your material supported $actual solid questions out of the $requested you aimed for. '
                'Start with these $actual, or add another material.',
                style: AppTypography.quizDialogBody,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              AppButton(
                label: 'Start with these',
                onPressed: () => Navigator.of(context).pop(true),
                height: 52,
                shadowColor: AppColors.navy.withValues(alpha: 0.10),
              ),
              const SizedBox(height: 10),
              AppButton(
                label: 'Change the setup',
                variant: AppButtonVariant.outlinedNeutral,
                height: 46,
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
                  decoration: const BoxDecoration(
                    color: AppColors.navy,
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
                  ),
                  child: Row(
                    children: [
                      QuizIconButton(
                        icon: Icons.arrow_back,
                        semanticLabel: 'Back',
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(width: 13),
                      Text('Quiz setup', style: AppTypography.quizHeaderTitle),
                    ],
                  ),
                ),
                Expanded(
                  child: FutureBuilder<List<StudyMaterial>>(
                    future: _materialsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final materials = snapshot.data ?? const [];
                      return SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(22, 4, 22, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_errorMessage != null) ...[
                              _ErrorBanner(message: _errorMessage!),
                              const SizedBox(height: 16),
                            ],
                            _buildMaterialsSection(materials),
                            const SizedBox(height: 22),
                            _buildDifficultySection(),
                            const SizedBox(height: 22),
                            _buildCountSection(),
                            const SizedBox(height: 22),
                            _buildModeSection(),
                            const SizedBox(height: 22),
                            _buildExtraInstructionsSection(),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(22, 12, 22, 26),
                  color: Colors.white,
                  child: FutureBuilder<List<StudyMaterial>>(
                    future: _materialsFuture,
                    builder: (context, snapshot) {
                      final materials = snapshot.data ?? const [];
                      final canGenerate = !_generating &&
                          _selectedMaterialIds.isNotEmpty &&
                          _selectedDifficulties.isNotEmpty &&
                          snapshot.connectionState == ConnectionState.done;
                      return AppButton(
                        label: 'Generate quiz',
                        variant: AppButtonVariant.accent,
                        height: 56,
                        borderRadius: 18,
                        shadowColor: AppColors.navy.withValues(alpha: 0.10),
                        disabledBackgroundColor: AppColors.disabledRedFill,
                        disabledRemovesShadow: true,
                        onPressed: canGenerate ? () => _generate(materials) : null,
                      );
                    },
                  ),
                ),
              ],
            ),
            if (_generating)
              GenerationLoadingOverlay(
                config: kQuizLoadingConfig,
                fixedLine: buildGenerationFixedLine(
                  count: _count,
                  noun: 'questions',
                  difficulties: _selectedDifficulties,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaterialsSection(List<StudyMaterial> materials) {
    final summary = _selectedMaterialIds.isEmpty
        ? 'Select materials'
        : (_selectedMaterialIds.length == 1
            ? materials
                .firstWhere(
                  (m) => m.materialId == _selectedMaterialIds.first,
                  orElse: () => materials.isEmpty
                      ? StudyMaterial(materialId: '', title: '', type: '', document: '', courseId: '', extractedText: '')
                      : materials.first,
                )
                .title
            : '${_selectedMaterialIds.length} materials selected');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('MATERIALS', style: AppTypography.quizEyebrow),
        const SizedBox(height: 9),
        GestureDetector(
          onTap: () => setState(() => _materialsOpen = !_materialsOpen),
          child: Container(
            height: 54,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _materialsOpen ? AppColors.navy : AppColors.borderLight,
                width: 2,
              ),
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
                    style: AppTypography.quizOption(
                      FontWeight.w900,
                      color: _selectedMaterialIds.isEmpty ? AppColors.placeholder : AppColors.navy,
                    ),
                  ),
                ),
                Icon(
                  _materialsOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
        if (_materialsOpen)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.cardTint, width: 2),
            ),
            child: materials.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      'No materials available for this course yet.',
                      style: AppTypography.quizEmptyBody,
                    ),
                  )
                : Column(
                    children: materials.map((m) {
                      final on = _selectedMaterialIds.contains(m.materialId);
                      return _MaterialRow(
                        material: m,
                        selected: on,
                        onTap: () => setState(() {
                          if (on) {
                            _selectedMaterialIds.remove(m.materialId);
                          } else {
                            _selectedMaterialIds.add(m.materialId);
                          }
                        }),
                      );
                    }).toList(),
                  ),
          ),
      ],
    );
  }

  Widget _buildDifficultySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('DIFFICULTY', style: AppTypography.quizEyebrow),
        const SizedBox(height: 9),
        Row(
          children: DifficultyLevel.values.map((level) {
            final on = _selectedDifficulties.contains(level);
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: level == DifficultyLevel.values.last ? 0 : 8,
                ),
                child: GestureDetector(
                  onTap: () => setState(() {
                    if (on) {
                      if (_selectedDifficulties.length > 1) {
                        _selectedDifficulties.remove(level);
                      }
                    } else {
                      _selectedDifficulties.add(level);
                    }
                  }),
                  child: Container(
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: on ? AppColors.navy : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: on ? AppColors.navy : AppColors.borderDefault, width: 2),
                    ),
                    child: Text(
                      _difficultyLabel(level),
                      style: AppTypography.quizOption(
                        FontWeight.w900,
                        color: on ? Colors.white : AppColors.disabledMuted,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCountSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('QUESTIONS TO AIM FOR', style: AppTypography.quizEyebrow),
        const SizedBox(height: 9),
        _CountStepper(
          count: _count,
          onChanged: (value) => setState(() => _count = value),
        ),
      ],
    );
  }

  Widget _buildModeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('MODE', style: AppTypography.quizEyebrow),
        const SizedBox(height: 9),
        _ModeCard(
          icon: Icons.description_outlined,
          title: 'Exam Mode',
          subtitle: "Answer everything first. No exit until you submit.",
          selected: _mode == Mode.exam,
          onTap: () => setState(() => _mode = Mode.exam),
        ),
        const SizedBox(height: 8),
        _ModeCard(
          icon: Icons.school_outlined,
          title: 'Learning Mode',
          subtitle: 'Feedback, explanation and source after each one.',
          selected: _mode == Mode.learning,
          onTap: () => setState(() => _mode = Mode.learning),
        ),
      ],
    );
  }

  Widget _buildExtraInstructionsSection() {
    final length = _promptController.text.length;
    final atLimit = length >= 300;
    final approaching = length >= 260;
    final counterColor = atLimit
        ? AppColors.errorText
        : (approaching ? AppColors.warningText : AppColors.placeholder);
    final edgeColor = atLimit
        ? AppColors.red
        : (approaching ? const Color(0xFFF5A524) : AppColors.borderLight);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('EXTRA INSTRUCTIONS ', style: AppTypography.quizEyebrow),
            Text('· OPTIONAL', style: AppTypography.quizEyebrow.copyWith(color: AppColors.textOnDisabled)),
          ],
        ),
        const SizedBox(height: 9),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _promptChips.map((chip) {
            return GestureDetector(
              onTap: () {
                final next = chip.length > 300 ? chip.substring(0, 300) : chip;
                _promptController.text = next;
                _promptController.selection = TextSelection.collapsed(offset: next.length);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.borderDefault, width: 2),
                ),
                child: Text(chip, style: AppTypography.quizOption(FontWeight.w900, color: AppColors.disabledMuted).copyWith(fontSize: 12)),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _promptController,
          maxLength: 300,
          maxLines: 3,
          buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
          decoration: InputDecoration(
            hintText: 'e.g. include an example with each question',
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: edgeColor, width: 2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: edgeColor, width: 2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: edgeColor, width: 2),
            ),
          ),
          style: AppTypography.quizOption(FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              atLimit ? 'Character limit reached' : (approaching ? 'Approaching the limit' : ''),
              style: AppTypography.quizEmptyBody.copyWith(color: counterColor, fontSize: 11),
            ),
            Text('$length/300', style: AppTypography.quizBadge.copyWith(color: counterColor)),
          ],
        ),
      ],
    );
  }

  String _difficultyLabel(DifficultyLevel level) {
    switch (level) {
      case DifficultyLevel.easy:
        return 'Easy';
      case DifficultyLevel.medium:
        return 'Medium';
      case DifficultyLevel.hard:
        return 'Hard';
    }
  }
}

class _MaterialRow extends StatelessWidget {
  const _MaterialRow({required this.material, required this.selected, required this.onTap});

  final StudyMaterial material;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF4F6FF) : Colors.white,
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
              child: selected ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(material.title, style: AppTypography.quizOption(FontWeight.w900)),
            ),
            Text(material.type.toUpperCase(), style: AppTypography.quizBadge.copyWith(color: AppColors.placeholder)),
          ],
        ),
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.enabled, required this.onTap});

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 46,
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled ? AppColors.navy : AppColors.cardTint,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: enabled ? Colors.white : AppColors.textOnDisabled),
      ),
    );
  }
}

/// NOTE 13d: mirrors FlashcardSetupScreen's `_CountStepper` exactly (same
/// [_minQuestionCount]/[_maxQuestionCount] bounds, same commit-on-blur/
/// submit behavior, same digits-only input, same invalid/empty-input
/// fallback to the last valid count) — kept Quiz-local rather than
/// extracted into a cross-feature shared widget, so this file doesn't need
/// to touch or depend on the Flashcards feature's files at all.
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
  // is clamped to the same [_minQuestionCount, _maxQuestionCount] range as
  // the +/- buttons.
  void _commit() {
    final parsed = int.tryParse(_controller.text);
    final next = parsed == null
        ? widget.count
        : parsed.clamp(_minQuestionCount, _maxQuestionCount);
    _controller.text = '$next';
    if (next != widget.count) widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final atMin = widget.count <= _minQuestionCount;
    final atMax = widget.count >= _maxQuestionCount;

    return Row(
      children: [
        _StepperButton(
          icon: Icons.remove,
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
            style: AppTypography.quizOption(FontWeight.w900).copyWith(fontSize: 30),
            decoration: const InputDecoration(border: InputBorder.none, isDense: true),
          ),
        ),
        const SizedBox(width: 14),
        _StepperButton(
          icon: Icons.add,
          enabled: !atMax,
          onTap: () => widget.onChanged(widget.count + 1),
        ),
      ],
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: selected ? AppColors.navy : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? AppColors.navy : AppColors.borderDefault, width: 2),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? Colors.white.withValues(alpha: 0.18) : AppColors.cardTint,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, size: 19, color: selected ? Colors.white : AppColors.navy),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.quizOption(FontWeight.w900, color: selected ? Colors.white : AppColors.navy)),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTypography.quizEmptyBody.copyWith(
                      color: selected ? Colors.white.withValues(alpha: 0.7) : AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.errorBannerBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.errorBannerBorder),
      ),
      child: Text(message, style: AppTypography.bannerBody),
    );
  }
}
