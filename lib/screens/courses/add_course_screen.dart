import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/course.dart';
import '../../services/calendar_service.dart';
import '../../services/courses_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/keyboard_safe_padding.dart';
import '../../widgets/app_button.dart';
import '../../widgets/color_picker_dialog.dart';
import '../../widgets/color_swatch_tile.dart';
import '../../widgets/dismiss_keyboard_on_tap.dart';
import '../../widgets/screen_header.dart';
import '../../widgets/status_bar_style.dart';
import '../calendar/calendar_styles.dart'
    show defaultEventColor, hexFromColor;
import 'widgets/course_icon.dart';

/// No real cap — just a sanity bound so a pathological account can't make
/// this return an unbounded list. There are only [kCoursePresetColors.length]
/// presets to check against, so this only ever needs to comfortably exceed
/// that.
const _kAllStandaloneColorsLimit = 500;

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
    this.calendarService,
  });

  final String uid;
  final CoursesService coursesService;

  /// The student's current courses, used to validate name uniqueness and
  /// lock already-used preset colors — fetched once by the caller so this
  /// screen doesn't need its own round trip before it can render.
  final List<Course> existingCourses;

  /// Overridable for tests; defaults to the real Firebase-backed service.
  /// Used once, on open, to find which presets a standalone (course-less)
  /// calendar event already uses, so those are locked too.
  final CalendarService? calendarService;

  @override
  State<AddCourseScreen> createState() => _AddCourseScreenState();
}

class _AddCourseScreenState extends State<AddCourseScreen> {
  final _nameController = TextEditingController();
  late final CalendarService _calendarService =
      widget.calendarService ?? CalendarService();

  String? _selectedColor;

  /// True once the student has explicitly picked a tile or a dialog colour
  /// — after that, [_loadStandaloneTakenColors] must never override her
  /// choice, even if it resolves later, and even if that colour turns out
  /// to be taken.
  bool _colorPickedByUser = false;

  /// Distinct colours (upper-case) of the student's own standalone
  /// (course-less) events, loaded once on open — a colour any of these
  /// already uses is locked the same way a course's own colour is. Starts
  /// empty, which is exactly the correct fallback if the load fails or
  /// hasn't resolved yet: lock based on course colours only until then.
  Set<String> _standaloneTakenColors = {};

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
  void initState() {
    super.initState();
    _loadStandaloneTakenColors();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// True if [hex] is already claimed — by another of the student's
  /// courses, or by one of her standalone (course-less) calendar events —
  /// compared case-insensitively. The sole rule for whether a preset is
  /// locked, and for whether a dialog-picked colour is accepted.
  bool _isTaken(String hex) =>
      isColorTaken(hex, widget.existingCourses) ||
      _standaloneTakenColors.contains(hex.toUpperCase());

  /// The default preselection: [kDefaultCourseColor] (green) if free,
  /// else the amber preset if free, else the first preset in
  /// [kCoursePresetColors]' own order that's free — the same priority
  /// order Add Event's own colour row uses (`defaultEventColor`), kept to
  /// whichever of those is actually a free preset here. If every preset
  /// is taken, there's nothing to preselect — the student must use "+"
  /// herself.
  String? get _defaultPreselection {
    final taken = {
      for (final course in widget.existingCourses) course.color.toUpperCase(),
      ..._standaloneTakenColors,
    };
    final pick = defaultEventColor(taken);
    final isFreePreset =
        kCoursePresetColors.any((p) => p.toUpperCase() == pick.toUpperCase()) &&
        !_isTaken(pick);
    return isFreePreset ? pick : null;
  }

  /// Loads which colours a standalone event already uses. Best-effort: a
  /// failed read falls back to locking based on course colours only — it
  /// never blocks the screen or shows an error, and that's also exactly
  /// the state before this resolves.
  Future<void> _loadStandaloneTakenColors() async {
    var standalone = const <String>[];
    try {
      standalone = await _calendarService.standaloneEventColorsMostRecentFirst(
        widget.uid,
        limit: _kAllStandaloneColorsLimit,
        fetchCap: null,
      );
    } catch (_) {
      // Falls back to the course-only lock above.
    }
    if (!mounted) return;
    setState(() {
      _standaloneTakenColors = standalone.map((h) => h.toUpperCase()).toSet();
      // Only preselect once the real lock set is known, and only if the
      // student hasn't already picked something herself in the meantime —
      // and never override an already-picked colour even if it turns out
      // to be taken.
      if (!_colorPickedByUser) _selectedColor = _defaultPreselection;
    });
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
      _colorPickedByUser = true;
      _errorMessage = null;
    });
  }

  Future<void> _pickCustomColor() async {
    final initial = parseHexColor(_selectedColor ?? kDefaultCourseColor);
    final picked = await showColorPicker(context: context, initial: initial);
    if (picked == null) return;
    final hex = hexFromColor(picked);
    // The same lock that keeps a preset untappable also blocks a
    // dialog-picked colour that happens to match a taken one — silently
    // ignored, same as tapping a locked preset tile.
    if (_isTaken(hex)) return;
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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: statusBarStyleFor(AppColors.navy),
      child: Scaffold(
      // The Save course footer below is pinned outside the scroll area, at
      // the bottom of the Column — without this, opening the keyboard (e.g.
      // typing the course name) shrinks the Scaffold's body and drags that
      // footer up above it instead of letting the keyboard simply cover it.
      // See keyboardSafePadding below for the matching fix on the scroll
      // view's own padding.
      resizeToAvoidBottomInset: false,
      body: DismissKeyboardOnTap(
        child: SafeArea(
        top: false,
        child: Column(
          children: [
            ScreenHeader(
              title: 'Add course',
              subtitle: 'Create a course to organize your studies',
              backgroundColor: AppColors.navy,
              onClose: () => Navigator.of(context).pop(false),
            ),
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
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: keyboardSafePadding(
                      context,
                      const EdgeInsets.all(20),
                    ),
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
                          isTaken: _isTaken,
                          onPick: _pickColor,
                          onPickCustom: _pickCustomColor,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Colors already in use are locked.',
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
      ),
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

/// All five [kCoursePresetColors], always shown in the pool's own order,
/// plus the rainbow "+" tile — the original layout, restored exactly:
/// a preset [isTaken] is locked (dimmed, an "x", untappable) rather than
/// hidden, and the "+" tile itself shows as selected once the current
/// colour is a custom pick rather than getting a separate extra swatch.
///
/// Uses the shared [ColorSwatchTile]/[CustomColorSwatchTile] rather than
/// private copies: their rendering (fill, border, opacity, boxShadow, the
/// check/"x" icon) is pixel-identical to the original screen's own
/// `_Swatch`/`_CustomSwatch` — confirmed by diffing the two — so reusing
/// them changes nothing about how this grid looks.
class _ColorGrid extends StatelessWidget {
  const _ColorGrid({
    required this.selectedColor,
    required this.isTaken,
    required this.onPick,
    required this.onPickCustom,
  });

  final String? selectedColor;
  final bool Function(String hex) isTaken;
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
      // Not currently visible here — this screen's whole body is already
      // wrapped in a SafeArea, which consumes the ambient MediaQuery
      // padding before it reaches this grid — but set explicitly anyway so
      // this grid can never pick up the same inherited safe-area padding
      // Add Event's did, should that SafeArea ever move or narrow. See
      // add_event_screen.dart's identical grid for the full explanation.
      padding: EdgeInsets.zero,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1,
      children: [
        for (final preset in kCoursePresetColors)
          ColorSwatchTile(
            key: ValueKey(preset),
            color: parseHexColor(preset),
            hex: preset,
            locked: isTaken(preset),
            selected: _isPresetSelected(preset),
            onTap: () => onPick(preset),
          ),
        CustomColorSwatchTile(
          key: const ValueKey('custom-color'),
          selected: _isCustomSelected(),
          onTap: onPickCustom,
        ),
      ],
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
