import 'package:example_riverpod/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modularity_flutter/modularity_flutter.dart';

void main() {
  testWidgets('Riverpod Example: Overrides work and State updates',
      (tester) async {
    // 1. Load App
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // 2. Verify Dependency Injection from Modularity -> Riverpod
    // The app bar title should contain the token 'secret-token' injected via AuthService
    expect(find.text('Riverpod: secret-token'), findsOneWidget);

    // 3. Verify Initial Counter State
    expect(find.text('Count: 0'), findsOneWidget);

    // 4. Verify Module Scope Exists
    expect(find.byWidgetPredicate((w) => w is ModuleScope), findsOneWidget);

    // 5. Interact (Tap +)
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    // 6. Verify State Change
    expect(find.text('Count: 1'), findsOneWidget);
  });
}
