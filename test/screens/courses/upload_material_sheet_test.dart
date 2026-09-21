import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/models/study_material.dart';
import 'package:tadarab_app/services/courses_service.dart';
import 'package:tadarab_app/screens/courses/widgets/upload_material_sheet.dart';

import '../../helpers/fake_courses_service.dart';

PickedFile _fakeFile({String name = 'Lecture 1.pptx', String content = 'hi'}) {
  return (name: name, bytes: Uint8List.fromList(utf8.encode(content)));
}

Future<void> _openSheet(
  WidgetTester tester, {
  required FakeCoursesService service,
  List<StudyMaterial> existingMaterials = const [],
  Future<PickedFile?> Function()? pickFile,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showUploadMaterialSheet(
                context: context,
                uid: 'uid-1',
                courseId: 'c1',
                courseName: 'IS230',
                coursesService: service,
                existingMaterials: existingMaterials,
                pickFile: pickFile ?? (() async => _fakeFile()),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'idle: no file picked yet shows the drop zone, and Upload is a no-op',
    (tester) async {
      final service = FakeCoursesService();
      await _openSheet(tester, service: service, pickFile: () async => null);

      expect(find.text('Choose a file'), findsOneWidget);

      await tester.tap(find.text('Upload'));
      await tester.pump();

      expect(find.text('Choose a file'), findsOneWidget);
      expect(service.uploadMaterialCalls, 0);
    },
  );

  testWidgets('picking a file pre-fills the name and enables Upload', (
    tester,
  ) async {
    final service = FakeCoursesService(
      uploadGate: Completer<void>(),
    );
    await _openSheet(tester, service: service);

    await tester.tap(find.text('Choose a file'));
    await tester.pump();

    expect(find.text('Lecture 1'), findsOneWidget);
  });

  testWidgets('duplicate material name: inline warning shown, Upload not '
      'triggered', (tester) async {
    final service = FakeCoursesService();
    await _openSheet(
      tester,
      service: service,
      existingMaterials: [
        StudyMaterial(
          materialId: 'm1',
          title: 'Lecture 1',
          type: 'pptx',
          document: 'd',
          courseId: 'c1',
          extractedText: 't',
        ),
      ],
    );

    await tester.tap(find.text('Choose a file'));
    await tester.pump();

    expect(
      find.text('You already have a material with this name in this course'),
      findsOneWidget,
    );

    await tester.tap(find.text('Upload'));
    await tester.pump();
    expect(service.uploadMaterialCalls, 0);
  });

  testWidgets('uploading: shows the progress state while the upload is in '
      'flight', (tester) async {
    final gate = Completer<void>();
    final service = FakeCoursesService(uploadGate: gate);
    await _openSheet(tester, service: service);

    await tester.tap(find.text('Choose a file'));
    await tester.pump();
    await tester.tap(find.text('Upload'));
    await tester.pump();

    expect(find.text('Uploading the file...'), findsOneWidget);

    gate.complete();
    await tester.pumpAndSettle(const Duration(seconds: 3));
  });

  testWidgets('success: shows the added-successfully message then '
      'auto-dismisses', (tester) async {
    final service = FakeCoursesService();
    await _openSheet(tester, service: service);

    await tester.tap(find.text('Choose a file'));
    await tester.pump();
    await tester.tap(find.text('Upload'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Added successfully to IS230'), findsOneWidget);

    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(find.text('Added successfully to IS230'), findsNothing);
  });

  testWidgets('empty-file error: rejects with a clear message and returns '
      'to idle so a different file can be chosen', (tester) async {
    final service = FakeCoursesService(
      uploadMaterialError: CoursesFailure('This file has no readable text.'),
    );
    await _openSheet(tester, service: service);

    await tester.tap(find.text('Choose a file'));
    await tester.pump();
    await tester.tap(find.text('Upload'));
    await tester.pumpAndSettle();

    expect(find.text('This file has no readable text.'), findsOneWidget);
    expect(find.text('Choose a file'), findsOneWidget);
  });
}
