import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../features/flashcards/flashcard_navigation.dart';
import '../../features/flashcards/screens/flashcard_sessions_screen.dart';
import '../../logic/materials_search.dart';
import '../../models/course.dart';
import '../../models/study_material.dart';
import '../../services/courses_service.dart';
import '../../services/flashcard_service.dart';
import '../../services/quiz_session_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/status_bar_style.dart';
import '../quiz/quiz_navigation.dart';
import '../quiz/quiz_sessions_screen.dart';
import 'widgets/delete_course_dialog.dart';
import 'widgets/delete_material_dialog.dart';
import 'widgets/upload_material_sheet.dart';

/// A course's detail screen: Study Tools (locked until the first material
/// exists), the materials list with type filters, and the trash icon that
/// starts the delete-course flow (courses_material_upload_spec.md §1/§3/§4).
///
/// Pops `true` if the course was deleted or its materials changed, so
/// [CoursesListScreen] knows to reload its "N materials" counts.
class CourseDetailScreen extends StatefulWidget {
  const CourseDetailScreen({
    super.key,
    required this.uid,
    required this.course,
    this.coursesService,
    this.flashcardService,
    this.pickFile,
  });

  final String uid;
  final Course course;
  final CoursesService? coursesService;

  /// Overridable for tests; defaults to the real Firebase-backed service.
  final FlashcardService? flashcardService;

  /// Overridable for tests — see [showUploadMaterialSheet]'s `pickFile`.
  final Future<PickedFile?> Function()? pickFile;

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  late final _service = widget.coursesService ?? CoursesService();
  late Future<List<StudyMaterial>> _materials = _service.fetchMaterials(
    widget.uid,
    widget.course.courseId,
  );
  bool _changed = false;
  bool _deleting = false;

  /// IDs of materials currently being deleted — tracked per-row (not one
  /// screen-wide flag like [_deleting]) so deleting one material doesn't
  /// freeze the rest of the list.
  final Set<String> _deletingMaterialIds = {};

  // Search/sort are deliberately plain State fields, not persisted
  // anywhere — leaving this screen (it's always pushed, never kept alive
  // in an IndexedStack the way Home's tabs are) disposes this whole State,
  // so "reset when leaving the screen" falls out of the normal widget
  // lifecycle with no extra code needed.
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  MaterialSortOrder _sortOrder = MaterialSortOrder.newestFirst;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() => _searchQuery = value);
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _searchQuery = '');
  }

  void _onSortChanged(MaterialSortOrder order) {
    setState(() => _sortOrder = order);
  }

  void _reload() {
    setState(() {
      _materials = _service.fetchMaterials(widget.uid, widget.course.courseId);
    });
  }

  Future<void> _openUpload(List<StudyMaterial> existingMaterials) async {
    final added = await showUploadMaterialSheet(
      context: context,
      uid: widget.uid,
      courseId: widget.course.courseId,
      courseName: widget.course.courseName,
      coursesService: _service,
      existingMaterials: existingMaterials,
      pickFile: widget.pickFile,
    );
    if (added) {
      _changed = true;
      _reload();
    }
  }

  void _openQuiz() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuizSessionsScreen(
          courseId: widget.course.courseId,
          courseName: widget.course.courseName,
          service: QuizSessionService(),
        ),
        settings: const RouteSettings(name: quizSessionsRouteName),
      ),
    );
  }

  void _openFlashcards() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FlashcardSessionsScreen(
          uid: widget.uid,
          courseId: widget.course.courseId,
          email: widget.course.email,
          service: widget.flashcardService,
        ),
        settings: const RouteSettings(name: flashcardSessionsRouteName),
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDeleteCourseDialog(
      context: context,
      courseName: widget.course.courseName,
    );
    if (!confirmed || _deleting) return;

    setState(() => _deleting = true);
    try {
      await _service.deleteCourse(widget.uid, widget.course.courseId);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on CoursesFailure catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          action: SnackBarAction(label: 'Retry', onPressed: _confirmDelete),
        ),
      );
    }
  }

  Future<void> _confirmDeleteMaterial(StudyMaterial material) async {
    final confirmed = await showDeleteMaterialDialog(
      context: context,
      materialTitle: material.title,
    );
    if (!confirmed || _deletingMaterialIds.contains(material.materialId)) {
      return;
    }

    setState(() => _deletingMaterialIds.add(material.materialId));
    try {
      await _service.deleteMaterial(
        widget.uid,
        widget.course.courseId,
        material,
      );
      if (!mounted) return;
      _changed = true;
      setState(() => _deletingMaterialIds.remove(material.materialId));
      _reload();
    } on CoursesFailure catch (e) {
      if (!mounted) return;
      setState(() => _deletingMaterialIds.remove(material.materialId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () => _confirmDeleteMaterial(material),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final courseColor = parseHexColor(widget.course.color);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: statusBarStyleFor(courseColor),
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          Navigator.of(context).pop(_changed);
        },
        child: Scaffold(
          body: SafeArea(
            top: false,
            child: FutureBuilder<List<StudyMaterial>>(
              future: _materials,
              builder: (context, snapshot) {
                final loading =
                    snapshot.connectionState != ConnectionState.done;
                final hasError = snapshot.hasError;
                final materials = snapshot.data ?? const <StudyMaterial>[];
                final hasMaterials =
                    !loading && !hasError && materials.isNotEmpty;

                return Column(
                  children: [
                    _Header(
                      course: widget.course,
                      color: courseColor,
                      onBack: () => Navigator.of(context).pop(_changed),
                      onDelete: _deleting ? null : _confirmDelete,
                    ),
                    Expanded(
                      child: loading
                          ? const Center(child: CircularProgressIndicator())
                          : hasError
                          ? _ErrorState(onRetry: _reload)
                          : hasMaterials
                          ? _MaterialsScrollView(
                              materials: materials,
                              searchController: _searchController,
                              searchQuery: _searchQuery,
                              onSearchChanged: _onSearchChanged,
                              onClearSearch: _clearSearch,
                              sortOrder: _sortOrder,
                              onSortChanged: _onSortChanged,
                              onUpload: () => _openUpload(materials),
                              onDeleteMaterial: _confirmDeleteMaterial,
                              deletingMaterialIds: _deletingMaterialIds,
                              onQuizTap: _openQuiz,
                              onFlashcardsTap: _openFlashcards,
                            )
                          // No materials yet: Study Tools stays fixed at the
                          // top (locked, as always); the "Add your first
                          // material" card — including its own "Course
                          // materials" heading, see _EmptyMaterials — centers
                          // in the remaining space below it, both
                          // horizontally and vertically. Expanded needs a
                          // bounded parent, so it wraps the LayoutBuilder
                          // (legitimate here — this outer Column is itself
                          // inside the grandparent's Expanded, so bounded) —
                          // not anything inside the SingleChildScrollView's
                          // child slot below, which always gets an unbounded
                          // max height; centering there is done by the inner
                          // Column's own `mainAxisAlignment: center` against
                          // a ConstrainedBox(minHeight:) floor instead, the
                          // standard "center if it fits, scroll if it
                          // doesn't" pattern, so a short screen scrolls
                          // instead of overflowing.
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    18,
                                    20,
                                    0,
                                  ),
                                  child: _StudyTools(
                                    unlocked: false,
                                    onQuizTap: _openQuiz,
                                    onFlashcardsTap: _openFlashcards,
                                  ),
                                ),
                                Expanded(
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      return SingleChildScrollView(
                                        child: ConstrainedBox(
                                          constraints: BoxConstraints(
                                            minHeight: constraints.maxHeight,
                                          ),
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Padding(
                                                padding: const EdgeInsets.all(
                                                  20,
                                                ),
                                                child: _EmptyMaterials(
                                                  onUpload: () =>
                                                      _openUpload(materials),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.course,
    required this.color,
    required this.onBack,
    required this.onDelete,
  });

  final Course course;
  final Color color;
  final VoidCallback onBack;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _CircleButton(icon: Icons.arrow_back, onTap: onBack),
                _CircleButton(icon: Icons.delete_outline, onTap: onDelete),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              course.courseName,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.02 * 28,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 20,
          color: onTap == null
              ? Colors.white.withValues(alpha: 0.5)
              : Colors.white,
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Couldn't load this course's materials.",
              style: AppTypography.subtitle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            AppButton(
              label: 'Retry',
              onPressed: onRetry,
              variant: AppButtonVariant.outlinedBrand,
              height: AppDimens.secondaryButtonHeight,
            ),
          ],
        ),
      ),
    );
  }
}

class _StudyTools extends StatelessWidget {
  const _StudyTools({
    required this.unlocked,
    required this.onQuizTap,
    required this.onFlashcardsTap,
  });

  final bool unlocked;
  final VoidCallback onQuizTap;
  final VoidCallback onFlashcardsTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Study tools',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        Opacity(
          opacity: unlocked ? 1 : 0.45,
          child: Row(
            children: [
              Expanded(
                child: _StudyToolTile(
                  icon: Icons.menu_book,
                  label: 'Quiz',
                  background: AppColors.cardTint,
                  iconColor: AppColors.navy,
                  labelColor: AppColors.navy,
                  // rgba(11,15,91,0.1) in the design handoff's own Quiz
                  // tile (MaterialsSearchScreen.dc.html).
                  shadowColor: AppColors.navy.withValues(alpha: 0.1),
                  onTap: unlocked ? onQuizTap : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StudyToolTile(
                  icon: Icons.style,
                  label: 'Flashcards',
                  background: AppColors.errorBannerBackground,
                  iconColor: AppColors.red,
                  labelColor: AppColors.errorBannerHeading,
                  // rgba(227,27,35,0.18) in the design handoff's own
                  // Flashcards tile (MaterialsSearchScreen.dc.html).
                  shadowColor: AppColors.red.withValues(alpha: 0.18),
                  onTap: unlocked ? onFlashcardsTap : null,
                ),
              ),
            ],
          ),
        ),
        if (!unlocked) ...[
          const SizedBox(height: 8),
          Text(
            'Upload a material to unlock quizzes and flashcards.',
            style: AppTypography.subtitle.copyWith(fontSize: 12),
          ),
        ],
      ],
    );
  }
}

class _StudyToolTile extends StatelessWidget {
  const _StudyToolTile({
    required this.icon,
    required this.label,
    required this.background,
    required this.iconColor,
    required this.labelColor,
    required this.shadowColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color background;
  final Color iconColor;
  final Color labelColor;
  final Color shadowColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 18),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(22),
          // Hard shadow (no blur), per the design handoff — but only when
          // the tile is actually tappable: the whole Study Tools row is
          // already wrapped in Opacity when locked (see _StudyTools), so
          // a flat/disabled tile should look exactly as flat as it does
          // today, not a faded shadow.
          boxShadow: onTap == null
              ? null
              : [BoxShadow(color: shadowColor, offset: const Offset(0, 3))],
        ),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, size: 24, color: iconColor),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: labelColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The "has materials" state's whole scrollable body: Study Tools and the
/// "Course materials"/Upload row scroll away normally, while the search +
/// sort row stays pinned under the course header (courses_material_
/// upload_spec's materials-search redesign, variant 1a "Filled pill" —
/// docs/mockups/design-handoff_MaterialsShearch/). A single outer
/// GestureDetector dismisses the keyboard on any tap that isn't claimed by
/// something more specific first (the search field itself, the sort
/// button, a row's delete button, ...) — `translucent` so it still lets
/// those claim the tap rather than racing them.
class _MaterialsScrollView extends StatelessWidget {
  const _MaterialsScrollView({
    required this.materials,
    required this.searchController,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.sortOrder,
    required this.onSortChanged,
    required this.onUpload,
    required this.onDeleteMaterial,
    required this.deletingMaterialIds,
    required this.onQuizTap,
    required this.onFlashcardsTap,
  });

  final List<StudyMaterial> materials;
  final TextEditingController searchController;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final MaterialSortOrder sortOrder;
  final ValueChanged<MaterialSortOrder> onSortChanged;
  final VoidCallback onUpload;
  final ValueChanged<StudyMaterial> onDeleteMaterial;
  final Set<String> deletingMaterialIds;
  final VoidCallback onQuizTap;
  final VoidCallback onFlashcardsTap;

  @override
  Widget build(BuildContext context) {
    final visible = sortMaterials(
      filterMaterialsByQuery(materials, searchQuery),
      sortOrder,
    );
    // Scales with the system text size (not just a fixed 46dp) so the
    // pinned row can't clip/overflow under a large accessibility font —
    // 46 is the design's own value at the default (1.0) scale.
    final scaledFontSize = MediaQuery.textScalerOf(context)
        .scale(_kSearchFieldFontSize);
    final fieldHeight = math.max(46.0, scaledFontSize * 1.6 + 20.0);
    final headerExtent = 12 + fieldHeight + 10;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.translucent,
      child: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StudyTools(
                    unlocked: true,
                    onQuizTap: onQuizTap,
                    onFlashcardsTap: onFlashcardsTap,
                  ),
                  const SizedBox(height: 18),
                  _MaterialsSectionHeader(onUpload: onUpload),
                ],
              ),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _SearchSortHeaderDelegate(
              extent: headerExtent,
              child: _SearchSortRow(
                controller: searchController,
                query: searchQuery,
                onChanged: onSearchChanged,
                onClear: onClearSearch,
                sortOrder: sortOrder,
                onSortChanged: onSortChanged,
                fieldHeight: fieldHeight,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            sliver: visible.isEmpty
                ? SliverToBoxAdapter(
                    child: _NoResultsCard(
                      query: searchQuery,
                      onClear: onClearSearch,
                    ),
                  )
                : SliverList.separated(
                    itemCount: visible.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final material = visible[i];
                      return _MaterialRow(
                        material: material,
                        query: searchQuery,
                        onDelete: () => onDeleteMaterial(material),
                        isDeleting: deletingMaterialIds.contains(
                          material.materialId,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

const _kSearchFieldFontSize = 15.0;

/// Fixed-height sliver that pins the search + sort row under the header —
/// [extent] is computed by the caller (see [_MaterialsScrollView]) from the
/// current text scale, so it's never a compile-time constant here.
class _SearchSortHeaderDelegate extends SliverPersistentHeaderDelegate {
  _SearchSortHeaderDelegate({required this.extent, required this.child});

  final double extent;
  final Widget child;

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _SearchSortHeaderDelegate oldDelegate) {
    return extent != oldDelegate.extent || child != oldDelegate.child;
  }
}

class _MaterialsSectionHeader extends StatelessWidget {
  const _MaterialsSectionHeader({required this.onUpload});

  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Course materials',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
        ),
        GestureDetector(
          onTap: onUpload,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: AppColors.navy,
              borderRadius: BorderRadius.circular(999),
              boxShadow: const [
                BoxShadow(color: AppColors.navyShadow, offset: Offset(0, 3)),
              ],
            ),
            child: const Text(
              '+ Upload',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The filled-pill search field + round sort button (variant 1a). Owns its
/// own [FocusNode] purely for the field's focused-vs-not visual state
/// (border/background) — the query text itself is fully controlled by the
/// caller via [controller]/[onChanged], so nothing here is lost if this
/// widget rebuilds.
class _SearchSortRow extends StatefulWidget {
  const _SearchSortRow({
    required this.controller,
    required this.query,
    required this.onChanged,
    required this.onClear,
    required this.sortOrder,
    required this.onSortChanged,
    required this.fieldHeight,
  });

  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final MaterialSortOrder sortOrder;
  final ValueChanged<MaterialSortOrder> onSortChanged;
  final double fieldHeight;

  @override
  State<_SearchSortRow> createState() => _SearchSortRowState();
}

class _SearchSortRowState extends State<_SearchSortRow> {
  final FocusNode _focusNode = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChange);
  }

  void _handleFocusChange() {
    if (_focused != _focusNode.hasFocus) {
      setState(() => _focused = _focusNode.hasFocus);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasQuery = widget.query.isNotEmpty;
    final iconInk = _focused || hasQuery
        ? AppColors.navy
        : AppColors.placeholder;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Container(
            height: widget.fieldHeight,
            padding: const EdgeInsets.only(left: 14, right: 8),
            decoration: BoxDecoration(
              color: _focused ? Colors.white : AppColors.chipBackground,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: _focused ? AppColors.navy : Colors.transparent,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.search, size: 18, color: iconInk),
                const SizedBox(width: 9),
                Expanded(
                  child: Semantics(
                    label: 'Search materials',
                    textField: true,
                    child: TextField(
                      controller: widget.controller,
                      focusNode: _focusNode,
                      onChanged: widget.onChanged,
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: _kSearchFieldFontSize,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Search materials',
                        hintStyle: TextStyle(
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.w700,
                          color: AppColors.placeholder,
                        ),
                        isDense: true,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ),
                if (hasQuery) ...[
                  const SizedBox(width: 6),
                  Semantics(
                    button: true,
                    label: 'Clear search',
                    child: GestureDetector(
                      onTap: widget.onClear,
                      child: Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: AppColors.borderLight,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 12,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        _SortButton(
          sortOrder: widget.sortOrder,
          onSortChanged: widget.onSortChanged,
          size: widget.fieldHeight,
        ),
      ],
    );
  }
}

const _kSortOptionLabels = {
  MaterialSortOrder.newestFirst: 'Newest first',
  MaterialSortOrder.oldestFirst: 'Oldest first',
  MaterialSortOrder.aToZ: 'A to Z',
};

class _SortButton extends StatelessWidget {
  const _SortButton({
    required this.sortOrder,
    required this.onSortChanged,
    required this.size,
  });

  final MaterialSortOrder sortOrder;
  final ValueChanged<MaterialSortOrder> onSortChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    // "Applied" state (1a): the default (newestFirst) looks like the
    // field's own idle fill; any other choice turns the button solid navy
    // — no red dot (that's the outlined variant's own cue, not this one's).
    final applied = sortOrder != MaterialSortOrder.newestFirst;

    return Semantics(
      label: 'Sort materials',
      button: true,
      child: PopupMenuButton<MaterialSortOrder>(
        tooltip: '',
        initialValue: sortOrder,
        onSelected: onSortChanged,
        offset: Offset(0, size + 8),
        color: Colors.white,
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.cardTint, width: 2),
        ),
        itemBuilder: (context) => [
          const PopupMenuItem<MaterialSortOrder>(
            enabled: false,
            height: 30,
            child: Text(
              'SORT BY',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.06 * 11,
                color: AppColors.placeholder,
              ),
            ),
          ),
          for (final order in MaterialSortOrder.values)
            PopupMenuItem<MaterialSortOrder>(
              value: order,
              padding: EdgeInsets.zero,
              child: _SortMenuRow(
                label: _kSortOptionLabels[order]!,
                selected: order == sortOrder,
              ),
            ),
        ],
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: applied ? AppColors.navy : AppColors.chipBackground,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            Icons.sort,
            size: 19,
            color: applied ? Colors.white : AppColors.navy,
          ),
        ),
      ),
    );
  }
}

class _SortMenuRow extends StatelessWidget {
  const _SortMenuRow({required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        height: 44,
        decoration: BoxDecoration(
          color: selected ? AppColors.cardTint : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w800,
                  color: AppColors.navy,
                ),
              ),
            ),
            if (selected)
              const Icon(Icons.check, size: 17, color: AppColors.navy),
          ],
        ),
      ),
    );
  }
}

/// The "5 · No results" state: a search query that matched nothing. Same
/// dashed-border, calm-empty-state look as [_EmptyMaterials] (reuses
/// [AppColors.textOnDisabled] for the border, not a new color).
class _NoResultsCard extends StatelessWidget {
  const _NoResultsCard({required this.query, required this.onClear});

  final String query;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.textOnDisabled, width: 2),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.cardTint,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.search, size: 26, color: AppColors.navy),
          ),
          const SizedBox(height: 12),
          const Text(
            'No materials match',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 230),
            child: Text(
              'Nothing in this course has "${query.trim()}" in its name. '
              'Check the spelling or try a shorter word.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: onClear,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 6, horizontal: 10),
              child: Text(
                'Clear search',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: AppColors.red,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MaterialRow extends StatelessWidget {
  const _MaterialRow({
    required this.material,
    required this.query,
    required this.onDelete,
    required this.isDeleting,
  });

  final StudyMaterial material;
  final String query;
  final VoidCallback onDelete;
  final bool isDeleting;

  static const _titleStyle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w900,
    height: 1.25,
  );

  @override
  Widget build(BuildContext context) {
    final highlight = highlightMatch(material.title, query);
    final titleSpan = highlight == null
        ? TextSpan(text: material.title, style: _titleStyle)
        : TextSpan(
            children: [
              TextSpan(text: highlight.before, style: _titleStyle),
              TextSpan(
                text: highlight.match,
                style: _titleStyle.copyWith(color: AppColors.red),
              ),
              TextSpan(text: highlight.after, style: _titleStyle),
            ],
          );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Color(0x140B0F5B), offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.cardTint,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              material.type.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: AppColors.navy,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text.rich(titleSpan)),
          const SizedBox(width: 8),
          if (isDeleting)
            const Padding(
              padding: EdgeInsets.all(7),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation(AppColors.navy),
                ),
              ),
            )
          else
            GestureDetector(
              onTap: onDelete,
              child: Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.errorBannerBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.delete_outline,
                  size: 17,
                  color: AppColors.red,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyMaterials extends StatelessWidget {
  const _EmptyMaterials({required this.onUpload});

  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Course materials',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.textOnDisabled, width: 2),
          ),
          child: Column(
            children: [
              Container(
                width: 60,
                height: 60,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.cardTint,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.note_add_outlined,
                  size: 28,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Add your first material',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 14),
              AppButton(
                label: 'Upload material',
                onPressed: onUpload,
                variant: AppButtonVariant.accent,
                height: 54,
              ),
              const SizedBox(height: 8),
              Text(
                'PPTX · DOCX · TXT · up to '
                '${kMaxMaterialFileSizeBytes ~/ (1024 * 1024)} MB',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.placeholder,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
