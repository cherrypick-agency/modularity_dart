import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modularity_flutter/modularity_flutter.dart';

class FailingModule extends Module {
  static int attempts = 0;

  @override
  void binds(Binder i) {}

  @override
  Future<void> onInit() async {
    attempts++;
    // Fail first 2 times
    if (attempts <= 2) {
      throw Exception("Network Error");
    }
  }
}

void main() {
  testWidgets('E2E Failure Scenario: Module Failure -> Retry -> Success',
      (tester) async {
    FailingModule.attempts = 0;

    await tester.pumpWidget(
      ModularityRoot(
        child: MaterialApp(
          home: ModuleScope(
            module: FailingModule(),
            child: const Text('Module Loaded!'),
          ),
        ),
      ),
    );

    // 1. First Load -> Error
    await tester.pump(); // Start init
    await tester.pump(
        const Duration(milliseconds: 100)); // Allow Future to complete/fail

    expect(find.text('Module Init Failed'), findsOneWidget);
    expect(find.text('Exception: Network Error'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    // 2. Retry 1 (Attempt 2 -> Still Fails)
    await tester.tap(find.text('Retry'));
    await tester.pump(); // Rebuild to show loading
    await tester.pump(const Duration(milliseconds: 100)); // Fail again

    expect(find.text('Module Init Failed'), findsOneWidget);

    // 3. Retry 2 (Attempt 3 -> Success)
    await tester.tap(find.text('Retry'));
    await tester.pump(); // Loading
    await tester.pump(const Duration(milliseconds: 100)); // Success
    await tester.pump(); // Build Child

    expect(find.text('Module Loaded!'), findsOneWidget);
    expect(FailingModule.attempts, 3);
  });
}
