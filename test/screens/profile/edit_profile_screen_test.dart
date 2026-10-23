import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/screens/profile/edit_profile_screen.dart';
import 'package:tadarab_app/services/profile_service.dart';
import 'package:tadarab_app/widgets/app_button.dart';

import '../../helpers/fake_profile_service.dart';

void main() {
  late FakeProfileService service;
  bool? popped;

  Future<void> pumpEdit(
    WidgetTester tester, {
    String name = 'Leen',
    String email = 'student@example.com',
    FakeProfileService? profileService,
  }) async {
    service = profileService ?? FakeProfileService();
    popped = null;
    tester.view.physicalSize = const Size(412, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                popped = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => EditProfileScreen(
                      uid: 'uid-1',
                      name: name,
                      email: email,
                      profileService: service,
                    ),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> typeName(WidgetTester tester, String value) async {
    await tester.enterText(find.byKey(const ValueKey('profile-name')), value);
    await tester.pumpAndSettle();
  }

  AppButton saveButton(WidgetTester tester) =>
      tester.widget<AppButton>(find.widgetWithText(AppButton, 'Save Changes'));

  group('initial state', () {
    testWidgets('seeds the field with the stored name', (tester) async {
      await pumpEdit(tester, name: 'Leen');

      expect(find.text('Edit Profile'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('profile-name')))
            .controller!
            .text,
        'Leen',
      );
    });

    testWidgets('shows the email locked, with the design\'s note', (
      tester,
    ) async {
      await pumpEdit(tester, email: 'leen@example.com');

      expect(find.text('EMAIL'), findsOneWidget);
      expect(find.text('leen@example.com'), findsOneWidget);
      expect(find.text(kEmailLockedNote), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    });

    testWidgets('the email is not an editable field', (tester) async {
      await pumpEdit(tester);

      // Only the name is a TextField — the email is plain text, so there is
      // nothing to type into.
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('Save starts disabled, since nothing has changed', (
      tester,
    ) async {
      await pumpEdit(tester);

      expect(saveButton(tester).onPressed, isNull);
    });
  });

  group('save gating', () {
    testWidgets('a changed name enables Save', (tester) async {
      await pumpEdit(tester, name: 'Leen');
      await typeName(tester, 'Leen Alhumaid');

      expect(saveButton(tester).onPressed, isNotNull);
    });

    testWidgets('typing the same name back disables Save again', (
      tester,
    ) async {
      await pumpEdit(tester, name: 'Leen');
      await typeName(tester, 'Leen Alhumaid');
      await typeName(tester, 'Leen');

      expect(saveButton(tester).onPressed, isNull);
    });

    testWidgets('whitespace around an unchanged name does not count', (
      tester,
    ) async {
      await pumpEdit(tester, name: 'Leen');
      await typeName(tester, '  Leen  ');

      expect(saveButton(tester).onPressed, isNull);
    });

    testWidgets('an empty name is rejected and explained', (tester) async {
      await pumpEdit(tester, name: 'Leen');
      await typeName(tester, '');

      expect(saveButton(tester).onPressed, isNull);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('name-note'))).data,
        kNameRequiredNote,
      );
    });

    testWidgets('a whitespace-only name is rejected', (tester) async {
      await pumpEdit(tester, name: 'Leen');
      await typeName(tester, '    ');

      expect(saveButton(tester).onPressed, isNull);
    });

    testWidgets('the note returns to its helper text once valid', (
      tester,
    ) async {
      await pumpEdit(tester, name: 'Leen');
      await typeName(tester, '');
      await typeName(tester, 'Leen A');

      expect(
        tester.widget<Text>(find.byKey(const ValueKey('name-note'))).data,
        kNameHelpNote,
      );
    });
  });

  group('saving', () {
    testWidgets('writes the trimmed name and pops true', (tester) async {
      await pumpEdit(tester, name: 'Leen');
      await typeName(tester, '  Leen Alhumaid  ');
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      expect(service.savedNames, ['Leen Alhumaid']);
      expect(popped, isTrue);
    });

    testWidgets('a failure shows the banner and stays on the screen', (
      tester,
    ) async {
      await pumpEdit(
        tester,
        name: 'Leen',
        profileService: FakeProfileService(
          nameError: ProfileFailure('Could not save your changes.'),
        ),
      );
      await typeName(tester, 'Leen Alhumaid');
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      expect(find.text("Couldn't save your changes"), findsOneWidget);
      expect(find.text('Could not save your changes.'), findsOneWidget);
      expect(popped, isNull);
    });
  });
}
