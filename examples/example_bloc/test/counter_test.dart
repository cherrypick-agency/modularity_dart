import 'package:example_bloc/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modularity_flutter/modularity_flutter.dart';

void main() {
  testWidgets('Bloc Example: Counter increments and resolves Cubit', (tester) async {
    // 1. Load App
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // 2. Verify Initial State
    expect(find.text('Count: 0'), findsOneWidget);
    expect(find.text('Bloc Example'), findsOneWidget);

    // 3. Verify Module Scope Exists
    expect(find.byWidgetPredicate((w) => w is ModuleScope), findsOneWidget);

    // 4. Interact (Tap +)
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump(); // Rebuild UI

    // 5. Verify State Change
    expect(find.text('Count: 1'), findsOneWidget);
  });
}

