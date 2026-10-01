import 'package:flutter/material.dart';

import '../../models/course.dart';
import '../../models/study_material.dart';
import '../../services/courses_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';
import '../placeholder_screen.dart';
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
    this.pickFile,
  });

  final String uid;
  final Course course;
  final CoursesService? coursesService;

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
  String? _typeFilter;
  bool _changed = false;
  bool _deleting = false;

  /// IDs of materials currently being deleted — tracked per-row (not one
  /// screen-wide flag like [_deleting]) so deleting one material doesn't
  /// freeze the rest of the list.
  final Set<String> _deletingMaterialIds = {};

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

  void _openStudyTool() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const PlaceholderScreen(label: 'Study tools screen')));
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        backgroundColor: AppColors.homeBackground,
        body: SafeArea(
          child: FutureBuilder<List<StudyMaterial>>(
            future: _materials,
            builder: (context, snapshot) {
              final loading = snapshot.connectionState != ConnectionState.done;
              final hasError = snapshot.hasError;
              final materials = snapshot.data ?? const <StudyMaterial>[];
              final hasMaterials = !loading && !hasError && materials.isNotEmpty;

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
                        : SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _StudyTools(
                                  unlocked: hasMaterials,
                                  onTap: _openStudyTool,
                                ),
                                const SizedBox(height: 18),
                                _MaterialsSection(
                                  materials: materials,
                                  typeFilter: _typeFilter,
                                  onTypeFilterChanged: (f) =>
                                      setState(() => _typeFilter = f),
                                  onUpload: () => _openUpload(materials),
                                  onDeleteMaterial: _confirmDeleteMaterial,
                                  deletingMaterialIds: _deletingMaterialIds,
                                ),
                              ],
                            ),
                          ),
                  ),
                ],
              );
            },
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _CircleButton(icon: Icons.arrow_back, onTap: onBack),
              _CircleButton(
                icon: Icons.delete_outline,
                onTap: onDelete,
              ),
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
          color: onTap == null ? Colors.white.withValues(alpha: 0.5) : Colors.white,
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
  const _StudyTools({required this.unlocked, required this.onTap});

  final bool unlocked;
  final VoidCallback onTap;

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
                  onTap: unlocked ? onTap : null,
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
                  onTap: unlocked ? onTap : null,
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
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color background;
  final Color iconColor;
  final Color labelColor;
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

class _MaterialsSection extends StatelessWidget {
  const _MaterialsSection({
    required this.materials,
    required this.typeFilter,
    required this.onTypeFilterChanged,
    required this.onUpload,
    required this.onDeleteMaterial,
    required this.deletingMaterialIds,
  });

  final List<StudyMaterial> materials;
  final String? typeFilter;
  final ValueChanged<String?> onTypeFilterChanged;
  final VoidCallback onUpload;
  final ValueChanged<StudyMaterial> onDeleteMaterial;
  final Set<String> deletingMaterialIds;

  @override
  Widget build(BuildContext context) {
    if (materials.isEmpty) {
      return _EmptyMaterials(onUpload: onUpload);
    }

    final filtered = typeFilter == null
        ? materials
        : materials.where((m) => m.type == typeFilter).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
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
        ),
        const SizedBox(height: 12),
        _TypeFilterTabs(
          materials: materials,
          selected: typeFilter,
          onChanged: onTypeFilterChanged,
        ),
        const SizedBox(height: 12),
        for (final material in filtered) ...[
          _MaterialRow(
            material: material,
            onDelete: () => onDeleteMaterial(material),
            isDeleting: deletingMaterialIds.contains(material.materialId),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _TypeFilterTabs extends StatelessWidget {
  const _TypeFilterTabs({
    required this.materials,
    required this.selected,
    required this.onChanged,
  });

  final List<StudyMaterial> materials;
  final String? selected;
  final ValueChanged<String?> onChanged;

  int _countFor(String? type) => type == null
      ? materials.length
      : materials.where((m) => m.type == type).length;

  @override
  Widget build(BuildContext context) {
    const types = <String?>[null, 'pptx', 'docx', 'txt'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final type in types) ...[
            _FilterChip(
              label: type == null ? 'All' : type.toUpperCase(),
              count: _countFor(type),
              active: selected == type,
              onTap: () => onChanged(type),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.count,
    required this.active,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.navy : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: active
              ? null
              : Border.all(color: AppColors.borderDefault, width: 2),
        ),
        child: Text(
          '$label $count',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: active ? Colors.white : AppColors.disabledMuted,
          ),
        ),
      ),
    );
  }
}

class _MaterialRow extends StatelessWidget {
  const _MaterialRow({
    required this.material,
    required this.onDelete,
    required this.isDeleting,
  });

  final StudyMaterial material;
  final VoidCallback onDelete;
  final bool isDeleting;

  @override
  Widget build(BuildContext context) {
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
          Expanded(
            child: Text(
              material.title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                height: 1.25,
              ),
            ),
          ),
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
