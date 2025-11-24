import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:complex_app/main.dart';

void main() {
  testWidgets('Complex App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the app starts and finds the HomePage (implied by finding some default content or at least not crashing)
    // Since we don't know exact strings in HomePage without reading it, we just check it pumps successfully.
    await tester.pumpAndSettle();

    // Verify MaterialApp is present
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
