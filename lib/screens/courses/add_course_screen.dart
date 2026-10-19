import 'package:flutter/material.dart';

import '../../models/course.dart';
import '../../services/courses_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';
import 'widgets/course_icon.dart';

/// Create-a-course screen, opened from the `+` header button or the
/// empty-state CTA on the courses list. Full-screen (navy header, X close)
/// per the design handoff — courses_material_upload_spec.md §1/§2 doesn't
/// specify sheet-vs-screen, and the mockup is unambiguous here.
///
/// Pops `true` if a course was created, so the caller knows to reload its
/// list; pops with no result (or `false`) if the student backs out.
class AddCourseScreen extends StatefulWidget {
  const AddCourseScreen({
    super.key,
    required this.uid,
    required this.coursesService,
    required this.existingCourses,
  });

  final String uid;
  final CoursesService coursesService;

  /// The student's current courses, used to validate name uniqueness and
  /// lock already-used preset colors — fetched once by the caller so this
  /// screen doesn't need its own round trip before it can render.
  final List<Course> existingCourses;

  @override
  State<AddCourseScreen> createState() => _AddCourseScreenState();
}

class _AddCourseScreenState extends State<AddCourseScreen> {
  final _nameController = TextEditingController();
  String? _selectedColor;
  bool _saving = false;
  String? _errorMessage;

  /// Key on the scrollable content's own `Column`, used once (see
  /// [_recordBaseContentHeight]) to measure its real rendered height so
  /// [_gapFor] can turn "how much room is actually free" into a gap size.
  final _contentKey = GlobalKey();

  static const _compactGap = 22.0;
  static const _maxGap = 56.0;

  /// The content's true height *excluding* the two section gaps — derived
  /// once from a real layout pass (see [_recordBaseContentHeight]), then
  /// reused as a pure input to [_gapFor] for any available height
  /// afterwards (including a shrunk viewport once the keyboard opens),
  /// with no further measuring needed.
  double? _baseContentHeight;
  bool _measurementScheduled = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// How big to make each of the two inter-section gaps, given the real
  /// bounded height actually available (from the outer `LayoutBuilder`,
  /// not the `SingleChildScrollView`'s always-unbounded child slot).
  /// Distributes a quarter of whatever's left over after the content's
  /// own height into the gaps, within [_compactGap]..[_maxGap] — so a
  /// short viewport (free space negative or small) falls back to
  /// [_compactGap], and the page is always still inside a
  /// `SingleChildScrollView` regardless, so it can never overflow even if
  /// this guesses too generously.
  double _gapFor(double availableHeight) {
    final base = _baseContentHeight;
    if (base == null) return _compactGap;
    final freeSpace = availableHeight - base;
    return (_compactGap + freeSpace * 0.25).clamp(_compactGap, _maxGap);
  }

  /// Schedules a one-time measurement of the content's real height (at
  /// whatever gap was in effect for that first layout — always
  /// [_compactGap], since [_gapFor] returns that until [_baseContentHeight]
  /// is known) right after the current frame, then backs out the
  /// gap-free baseline and triggers the one rebuild that applies the real
  /// gap. A no-op once [_baseContentHeight] is set, or while a prior call
  /// is already waiting on its callback.
  void _recordBaseContentHeight() {
    if (_baseContentHeight != null || _measurementScheduled) return;
    _measurementScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measurementScheduled = false;
      if (!mounted) return;
      final height = _contentKey.currentContext?.size?.height;
      if (height == null) return;
      setState(() => _baseContentHeight = height - 2 * _compactGap);
    });
  }

  String get _name => _nameController.text.trim();

  bool get _isDuplicateName =>
      _name.isNotEmpty && isCourseNameTaken(_name, widget.existingCourses);

  bool get _canSave =>
      _name.isNotEmpty && !_isDuplicateName && _selectedColor != null;

  void _pickColor(String color) {
    setState(() {
      _selectedColor = color;
      _errorMessage = null;
    });
  }

  Future<void> _pickCustomColor() async {
    final color = await showDialog<Color>(
      context: context,
      builder: (context) => _CustomColorDialog(initial: Colors.blue),
    );
    if (color == null) return;
    final hex =
        '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
    _pickColor(hex);
  }

  Future<void> _save() async {
    if (!_canSave || _saving) return;
    setState(() {
      _saving = true;
      _errorMessage = null;
    });
    try {
      await widget.coursesService.createCourse(
        widget.uid,
        courseName: _name,
        color: _selectedColor!,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on CoursesFailure catch (e) {
      setState(() {
        _saving = false;
        _errorMessage = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _Header(onClose: () => Navigator.of(context).pop(false)),
            Expanded(
              // LayoutBuilder sits outside the SingleChildScrollView so
              // `constraints.maxHeight` is the real, bounded viewport
              // height (the scroll view itself would report unbounded
              // height for anything measured from inside its child slot).
              // `_gapFor` turns that into a proportional gap once the
              // content's own height is known (see
              // `_recordBaseContentHeight`); until then, and on any short
              // viewport, it falls back to the original compact spacing.
              // The content is still inside a SingleChildScrollView either
              // way, so neither choice can ever overflow.
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final sectionGap = _gapFor(constraints.maxHeight);
                  _recordBaseContentHeight();
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      key: _contentKey,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Course name',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _NameField(
                          controller: _nameController,
                          hasError: _isDuplicateName,
                          onChanged: (_) => setState(() {}),
                        ),
                        if (_isDuplicateName) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'You already have a course named this',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.errorText,
                            ),
                          ),
                        ],
                        SizedBox(
                          key: const ValueKey('section-gap-1'),
                          height: sectionGap,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Course color',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              'Any color',
                              style: AppTypography.subtitle.copyWith(
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _ColorGrid(
                          selectedColor: _selectedColor,
                          existingCourses: widget.existingCourses,
                          onPick: _pickColor,
                          onPickCustom: _pickCustomColor,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Colors already used by another course are locked.',
                          style: AppTypography.subtitle.copyWith(fontSize: 12),
                        ),
                        SizedBox(
                          key: const ValueKey('section-gap-2'),
                          height: sectionGap,
                        ),
                        const Text(
                          'Preview',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _PreviewCard(name: _name, colorHex: _selectedColor),
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            _errorMessage!,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.errorText,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
              color: Colors.white,
              child: AppButton(
                label: 'Save course',
                onPressed: _canSave ? _save : null,
                loading: _saving,
                height: 58,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      decoration: const BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add course',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.02 * 26,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Create a course to organize your studies',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xB3FFFFFF),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onClose,
            child: Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Color(0x29FFFFFF),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 18, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _NameField extends StatelessWidget {
  const _NameField({
    required this.controller,
    required this.hasError,
    required this.onChanged,
  });

  final TextEditingController controller;
  final bool hasError;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('course-name-field-box'),
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasError ? AppColors.error : AppColors.borderDefault,
          width: 2,
        ),
      ),
      // A bare `TextField` as this Container's direct child has nothing to
      // center *within* — `textAlignVertical` alone doesn't fix it, since
      // (per Container.build()'s own widget composition, with `alignment`
      // left unset here) there's no `Align` inserted around the child, so
      // the field just paints at its own natural single-line height
      // starting from this box's top edge. `AppTextField` avoids this by
      // wrapping its `TextField` in a `Row` (default `crossAxisAlignment:
      // center`) — mirroring that exact, already-working structure here
      // centers both the hint and the typed text in the field's full
      // height, regardless of what `textAlignVertical` does on its own.
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: AppTypography.fieldInput,
              textAlignVertical: TextAlignVertical.center,
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: 'e.g. IS230',
                hintStyle: AppTypography.fieldInput.copyWith(
                  color: AppColors.placeholder,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorGrid extends StatelessWidget {
  const _ColorGrid({
    required this.selectedColor,
    required this.existingCourses,
    required this.onPick,
    required this.onPickCustom,
  });

  final String? selectedColor;
  final List<Course> existingCourses;
  final ValueChanged<String> onPick;
  final VoidCallback onPickCustom;

  bool _isPresetSelected(String preset) =>
      selectedColor != null &&
      selectedColor!.toUpperCase() == preset.toUpperCase();

  bool _isCustomSelected() =>
      selectedColor != null &&
      !kCoursePresetColors.any(
        (p) => p.toUpperCase() == selectedColor!.toUpperCase(),
      );

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 5,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1,
      children: [
        for (final preset in kCoursePresetColors)
          _Swatch(
            key: ValueKey(preset),
            color: parseHexColor(preset),
            locked: isColorTaken(preset, existingCourses),
            selected: _isPresetSelected(preset),
            onTap: () => onPick(preset),
          ),
        _CustomSwatch(selected: _isCustomSelected(), onTap: onPickCustom),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    super.key,
    required this.color,
    required this.locked,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool locked;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: locked ? null : onTap,
      child: Opacity(
        opacity: locked ? 0.3 : 1,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? AppColors.navy : Colors.transparent,
              width: 3,
            ),
            boxShadow: locked
                ? null
                : [
                    BoxShadow(
                      color: AppColors.navy.withValues(alpha: 0.15),
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Icon(
            selected
                ? Icons.check
                : locked
                ? Icons.close
                : null,
            size: 18,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _CustomSwatch extends StatelessWidget {
  const _CustomSwatch({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AppColors.navy : Colors.transparent,
            width: 3,
          ),
          gradient: const SweepGradient(
            colors: [
              Color(0xFFFF0000),
              Color(0xFFFFD400),
              Color(0xFF38D200),
              Color(0xFF00D4C8),
              Color(0xFF0066FF),
              Color(0xFF8A00E6),
              Color(0xFFFF00A8),
              Color(0xFFFF0000),
            ],
          ),
        ),
        child: Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.add, size: 16, color: AppColors.navy),
        ),
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.name, required this.colorHex});

  final String name;
  final String? colorHex;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.08),
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CourseIcon(
            color: colorHex == null ? AppColors.cardTint : parseHexColor(colorHex!),
            courseName: name,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name.isEmpty ? 'Course name' : name,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: name.isEmpty
                        ? AppColors.textOnDisabled
                        : AppColors.navy,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '0 materials',
                  style: AppTypography.subtitle.copyWith(fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomColorDialog extends StatefulWidget {
  const _CustomColorDialog({required this.initial});

  final Color initial;

  @override
  State<_CustomColorDialog> createState() => _CustomColorDialogState();
}

class _CustomColorDialogState extends State<_CustomColorDialog> {
  late double _hue = HSVColor.fromColor(widget.initial).hue;

  Color get _color => HSVColor.fromAHSV(1, _hue, 1, 1).toColor();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Pick a color'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: _color,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          const SizedBox(height: 16),
          Slider(
            value: _hue,
            min: 0,
            max: 360,
            activeColor: _color,
            onChanged: (v) => setState(() => _hue = v),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_color),
          child: const Text('Use this color'),
        ),
      ],
    );
  }
}
