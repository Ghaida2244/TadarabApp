import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../models/study_material.dart';
import '../../../services/courses_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/dashed_border.dart';

enum _Stage { idle, uploading, success }

/// A picked file reduced to just what this sheet needs — decoupled from
/// `package:file_picker`'s own [PlatformFile] so tests can supply one
/// without touching a platform channel (see [showUploadMaterialSheet]'s
/// `pickFile` override).
typedef PickedFile = ({String name, Uint8List bytes});

/// The file extension of [filename] (without the dot), lowercase, or '' if
/// it has none — mirrors `PlatformFile.extension`'s convention.
String _extensionOf(String filename) {
  final dot = filename.lastIndexOf('.');
  if (dot < 0 || dot == filename.length - 1) return '';
  return filename.substring(dot + 1).toLowerCase();
}

Future<PickedFile?> _defaultPickFile() async {
  final file = await FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: const ['pptx', 'docx', 'txt'],
  );
  if (file == null) return null;
  return (name: file.name, bytes: await file.readAsBytes());
}

/// The "Upload material" bottom sheet, opened from Course Detail's
/// `+ Upload` button or its empty-state CTA
/// (courses_material_upload_spec.md §4). Returns `true` if a material was
/// actually added, so the caller knows to reload.
Future<bool> showUploadMaterialSheet({
  required BuildContext context,
  required String uid,
  required String courseId,
  required String courseName,
  required CoursesService coursesService,
  required List<StudyMaterial> existingMaterials,
  Future<PickedFile?> Function()? pickFile,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => _UploadMaterialSheet(
      uid: uid,
      courseId: courseId,
      courseName: courseName,
      coursesService: coursesService,
      existingMaterials: existingMaterials,
      pickFile: pickFile ?? _defaultPickFile,
    ),
  );
  return result ?? false;
}

class _UploadMaterialSheet extends StatefulWidget {
  const _UploadMaterialSheet({
    required this.uid,
    required this.courseId,
    required this.courseName,
    required this.coursesService,
    required this.existingMaterials,
    required this.pickFile,
  });

  final String uid;
  final String courseId;
  final String courseName;
  final CoursesService coursesService;
  final List<StudyMaterial> existingMaterials;
  final Future<PickedFile?> Function() pickFile;

  @override
  State<_UploadMaterialSheet> createState() => _UploadMaterialSheetState();
}

class _UploadMaterialSheetState extends State<_UploadMaterialSheet> {
  final _nameController = TextEditingController();
  PickedFile? _picked;
  _Stage _stage = _Stage.idle;
  double _progress = 0;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String get _extension => _extensionOf(_picked?.name ?? '');
  String get _name => _nameController.text.trim();

  bool get _isDuplicateName =>
      _name.isNotEmpty &&
      isMaterialNameTaken(_name, widget.existingMaterials);

  bool get _isTooLarge =>
      _picked != null && _picked!.bytes.length > kMaxMaterialFileSizeBytes;

  bool get _canUpload =>
      _picked != null && _name.isNotEmpty && !_isDuplicateName && !_isTooLarge;

  Future<void> _pickFile() async {
    final picked = await widget.pickFile();
    if (picked == null) return;
    if (!mounted) return;
    setState(() {
      _picked = picked;
      _errorMessage = null;
      final dot = picked.name.lastIndexOf('.');
      _nameController.text = dot > 0
          ? picked.name.substring(0, dot)
          : picked.name;
    });
  }

  Future<void> _upload() async {
    final picked = _picked;
    if (!_canUpload || picked == null) return;
    setState(() {
      _stage = _Stage.uploading;
      _progress = 0;
      _errorMessage = null;
    });
    try {
      await widget.coursesService.uploadMaterial(
        uid: widget.uid,
        courseId: widget.courseId,
        title: _name,
        type: _extension,
        bytes: picked.bytes,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      if (!mounted) return;
      setState(() => _stage = _Stage.success);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) Navigator.of(context).pop(true);
      });
    } on CoursesFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _stage = _Stage.idle;
        _picked = null;
        _nameController.clear();
        _errorMessage = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.borderLight,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Upload material',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 14),
            switch (_stage) {
              _Stage.idle => _IdleContent(
                picked: _picked,
                nameController: _nameController,
                isDuplicateName: _isDuplicateName,
                isTooLarge: _isTooLarge,
                errorMessage: _errorMessage,
                canUpload: _canUpload,
                onPickFile: _pickFile,
                onNameChanged: (_) => setState(() {}),
                onUpload: _upload,
              ),
              _Stage.uploading => _UploadingContent(progress: _progress),
              _Stage.success => _SuccessContent(courseName: widget.courseName),
            },
          ],
        ),
      ),
    );
  }
}

class _IdleContent extends StatelessWidget {
  const _IdleContent({
    required this.picked,
    required this.nameController,
    required this.isDuplicateName,
    required this.isTooLarge,
    required this.errorMessage,
    required this.canUpload,
    required this.onPickFile,
    required this.onNameChanged,
    required this.onUpload,
  });

  final PickedFile? picked;
  final TextEditingController nameController;
  final bool isDuplicateName;
  final bool isTooLarge;
  final String? errorMessage;
  final bool canUpload;
  final VoidCallback onPickFile;
  final ValueChanged<String> onNameChanged;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (errorMessage != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.errorBannerBackground,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              errorMessage!,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.errorBannerBody,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        GestureDetector(
          onTap: onPickFile,
          child: Container(
            // The fill lives on this outer Container, not on
            // DashedRoundedBorder's own child: that child paints on top of
            // the dashes (CustomPaint draws its painter behind the child),
            // so an opaque fill there would hide the dashed border
            // entirely instead of just showing through its gaps.
            decoration: BoxDecoration(
              color: AppColors.surfaceFaint,
              borderRadius: BorderRadius.circular(20),
            ),
            child: DashedRoundedBorder(
              color: AppColors.textOnDisabled,
              borderRadius: 20,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 26,
                  horizontal: 18,
                ),
                child: Column(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.cardTint,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.add,
                        size: 22,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Choose a file',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'PPTX · DOCX · TXT · up to '
                      '${kMaxMaterialFileSizeBytes ~/ (1024 * 1024)} MB',
                      style: AppTypography.subtitle.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (picked != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.chipBackground,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    _extensionOf(picked!.name).toUpperCase(),
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDuplicateName
                                ? AppColors.error
                                : AppColors.borderDefault,
                            width: 2,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: TextField(
                          controller: nameController,
                          onChanged: onNameChanged,
                          style: AppTypography.fieldInput.copyWith(fontSize: 14),
                          decoration: const InputDecoration(
                            isCollapsed: true,
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap to rename · ${_extensionOf(picked!.name).toUpperCase()} · '
                        '${(picked!.bytes.length / (1024 * 1024)).toStringAsFixed(1)} MB',
                        style: AppTypography.subtitle.copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isDuplicateName) ...[
            const SizedBox(height: 8),
            const Text(
              'You already have a material with this name in this course',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.errorText,
              ),
            ),
          ],
          if (isTooLarge) ...[
            const SizedBox(height: 8),
            Text(
              'This file is larger than '
              '${kMaxMaterialFileSizeBytes ~/ (1024 * 1024)} MB.',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.errorText,
              ),
            ),
          ],
        ],
        const SizedBox(height: 16),
        // AppButton doesn't dim itself just for onPressed being null (only
        // for `loading`), so the pale-vs-solid disabled/enabled look this
        // button needs is applied here rather than inside the shared
        // widget — matching the same Opacity-based pattern already used
        // for the locked Study Tools tiles and locked color swatches.
        Opacity(
          opacity: canUpload ? 1 : 0.4,
          child: AppButton(
            label: 'Upload',
            onPressed: canUpload ? onUpload : null,
            variant: AppButtonVariant.accent,
            height: 56,
          ),
        ),
      ],
    );
  }
}

class _UploadingContent extends StatelessWidget {
  const _UploadingContent({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'AI',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Uploading the file...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress == 0 ? null : progress,
              minHeight: 10,
              backgroundColor: Colors.white.withValues(alpha: 0.18),
              valueColor: const AlwaysStoppedAnimation(AppColors.red),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuccessContent extends StatelessWidget {
  const _SuccessContent({required this.courseName});

  final String courseName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.successBackgroundStrong,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, size: 20, color: AppColors.success),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Added successfully to $courseName',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.successDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
