import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/screens/profile/edit_profile_screen.dart';
import 'package:tadarab_app/services/profile_service.dart';
import 'package:tadarab_app/theme/app_theme.dart';
import 'package:tadarab_app/widgets/app_button.dart';
import 'package:tadarab_app/widgets/screen_header.dart';

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

  group('keyboard inset', () {
    testWidgets(
      'the Save Changes footer does not move when the keyboard opens, and '
      'the name field stays reachable while typing',
      (tester) async {
        // pumpEdit sizes the view to 412x1200 itself; shrink to a small
        // phone height afterwards, since this is about a real keyboard
        // inset on a small screen.
        await pumpEdit(tester);
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        await tester.pumpAndSettle();

        final buttonFinder = find.widgetWithText(AppButton, 'Save Changes');
        final restRect = tester.getRect(buttonFinder);

        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(
          tester.getRect(buttonFinder),
          restRect,
          reason:
              'the footer must stay put, covered by the keyboard, not '
              'pushed up above it',
        );

        final nameFieldFinder = find.byKey(const ValueKey('profile-name'));
        await tester.ensureVisible(nameFieldFinder);
        await tester.pumpAndSettle();
        await tester.tap(nameFieldFinder);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(
          tester.getRect(nameFieldFinder).bottom,
          lessThanOrEqualTo(640 - 300),
          reason:
              'the focused field must be scrolled above the keyboard, not '
              'left behind it',
        );
      },
    );
  });

  group('dismiss keyboard', () {
    Future<void> pumpSmall(WidgetTester tester) async {
      await pumpEdit(tester);
      // Short enough that the form's two fields genuinely overflow and
      // need to scroll — Edit Profile's content is short enough to fit
      // at a plain 360x640 without scrolling at all. Not shorter than
      // this: the now-taller unified ScreenHeader (see screen_header.dart)
      // needs enough room left over for the EMAIL field to still land
      // inside the viewport's hit-testable area.
      tester.view.physicalSize = const Size(360, 480);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpAndSettle();
    }

    testWidgets('tapping an empty area of the form unfocuses the field', (
      tester,
    ) async {
      await pumpSmall(tester);

      await tester.tap(find.byKey(const ValueKey('profile-name')));
      await tester.pumpAndSettle();
      expect(tester.testTextInput.isVisible, isTrue);

      // A static label with no gesture handler of its own — the tap can
      // only be caught by the wrapping dismiss-on-tap handler.
      await tester.tap(find.text('EMAIL'));
      await tester.pumpAndSettle();

      expect(tester.testTextInput.isVisible, isFalse);
    });

    testWidgets('dragging the form unfocuses the field', (tester) async {
      await pumpSmall(tester);

      await tester.tap(find.byKey(const ValueKey('profile-name')));
      await tester.pumpAndSettle();
      expect(tester.testTextInput.isVisible, isTrue);

      await tester.drag(find.text('EMAIL'), const Offset(0, -200));
      await tester.pumpAndSettle();

      expect(tester.testTextInput.isVisible, isFalse);
    });
  });

  testWidgets(
    'the header is the shared ScreenHeader, the same height as Add '
    "course's own (title-only, no subtitle)",
    (tester) async {
      await pumpEdit(tester);

      final headerFinder = find.byType(ScreenHeader);
      expect(headerFinder, findsOneWidget);
      final realHeight = tester.getSize(headerFinder).height;

      // Add course's own header is taller only because it also carries a
      // subtitle ('Create a course to organize your studies') — padding,
      // title style, button size and border radius are the exact same
      // ScreenHeader component either way, so the fair comparison is
      // against a title-only instance (no subtitle, matching this
      // screen), not Add course's actual subtitled height.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ScreenHeader(
                  title: 'Add course',
                  backgroundColor: AppColors.navy,
                  onClose: () {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      final referenceHeight = tester.getSize(find.byType(ScreenHeader)).height;

      expect(realHeight, referenceHeight);
    },
  );

  testWidgets('the back chevron sits to the left of the title', (
    tester,
  ) async {
    await pumpEdit(tester);

    final screenHeader = tester.widget<ScreenHeader>(
      find.byType(ScreenHeader),
    );
    expect(screenHeader.buttonOnStart, isTrue);

    final buttonX = tester.getTopLeft(find.byIcon(Icons.chevron_left)).dx;
    final titleX = tester.getTopLeft(find.text('Edit Profile')).dx;
    expect(buttonX, lessThan(titleX));
  });

  testWidgets('tapping the back chevron pops', (tester) async {
    await pumpEdit(tester);

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();

    expect(find.byType(EditProfileScreen), findsNothing);
    expect(popped, isNull);
  });
}
