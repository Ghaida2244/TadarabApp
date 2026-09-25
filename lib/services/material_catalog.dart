import '../models/study_material.dart';

/// Where Quiz Setup gets its list of materials for a course, and the text
/// sent to the generation Worker for each one.
///
/// Two implementations: [StubMaterialCatalog] (used by the running app
/// today) and, once the Courses & Material upload feature (Manar,
/// `feature/courses`) lands and `StudyMaterial` exposes real extracted
/// text, a Firestore-backed implementation swaps in here —
/// [QuizSessionService] (see quiz_session_service.dart) only depends on
/// this interface, so nothing else changes.
abstract class MaterialCatalog {
  /// The materials available to pick from for [courseId].
  Future<List<StudyMaterial>> fetchMaterials(String courseId);

  /// The text sent to the generation Worker for [material].
  Future<String> sourceTextFor(StudyMaterial material);
}

/// Deterministic seed materials + source text, so the Quiz feature's whole
/// pipeline (setup -> generate -> play -> summary) can be built, run, and
/// tested for real before the Courses/upload feature exists and before any
/// student has uploaded anything. Content is short, real study material
/// (not lorem ipsum) so a real generation call produces sensible output.
class StubMaterialCatalog implements MaterialCatalog {
  const StubMaterialCatalog();

  static const _seedMaterials = [
    (
      idSuffix: 'seed-databases',
      title: 'Lecture 1 — Introduction to Databases',
      type: 'pptx',
      sourceText:
          '[Slide 1]\n'
          'A database is a collection of related data representing some aspect '
          'of the real world, organised so it can be accessed, managed and '
          'updated. Data are known facts that can be recorded and that have an '
          'implicit meaning.\n\n'
          '[Slide 2]\n'
          'A Database Management System (DBMS) is the software layer between '
          'the user (or an application) and the stored data. Every read and '
          'write to the database passes through the DBMS.\n\n'
          '[Slide 3]\n'
          'The database approach centralises data management using a DBMS so '
          'many users and applications can share the same data, instead of each '
          'department keeping its own separate files. Advantages include '
          'controlled redundancy, shared access, and data independence. A '
          'disadvantage is that it usually requires more capable (and more '
          'expensive) hardware than a simple file-based system.\n\n'
          '[Slide 4]\n'
          'A schema is the description of the structure and constraints of the '
          'data — it rarely changes. An instance is the actual data stored in '
          'the database at a particular moment in time — it changes constantly '
          'as data is inserted, updated, and deleted.',
    ),
    (
      idSuffix: 'seed-photosynthesis',
      title: 'Lecture 2 — Photosynthesis',
      type: 'docx',
      sourceText:
          '[Paragraph 1]\n'
          'Photosynthesis is the process by which green plants use sunlight, '
          'water, and carbon dioxide to produce glucose and oxygen. It occurs '
          'mainly in the chloroplasts of plant cells, using a green pigment '
          'called chlorophyll to absorb light energy.\n\n'
          '[Paragraph 2]\n'
          'The overall chemical equation for photosynthesis is: '
          '6CO2 + 6H2O + light energy -> C6H12O6 + 6O2. This reaction has two '
          'main stages: the light-dependent reactions, which occur in the '
          'thylakoid membrane, and the light-independent reactions (the Calvin '
          'cycle), which occur in the stroma.',
    ),
  ];

  @override
  Future<List<StudyMaterial>> fetchMaterials(String courseId) async {
    return _seedMaterials
        .map(
          (m) => StudyMaterial(
            materialId: '$courseId-${m.idSuffix}',
            title: m.title,
            type: m.type,
            document: '',
            courseId: courseId,
          ),
        )
        .toList();
  }

  @override
  Future<String> sourceTextFor(StudyMaterial material) async {
    for (final m in _seedMaterials) {
      if (material.materialId.endsWith(m.idSuffix)) return m.sourceText;
    }
    // A material this catalog didn't produce (shouldn't happen while this
    // stub is the only source) — fall back rather than crash generation.
    return '[Material: ${material.title}]\nNo source text available.';
  }
}
