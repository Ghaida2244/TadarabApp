import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tadarab_app/main.dart';

void main() {
  testWidgets('App builds and shows the Firebase bootstrap screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const TadarabApp());

    // Firebase.initializeApp() has no test fake here, so the app should show
    // the loading state rather than crash while it's pending.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
