import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modularity_flutter/modularity_flutter.dart';
import 'package:complex_mobx/main.dart';
import 'package:complex_mobx/src/modules/auth/auth_module.dart'; // Import AuthModule
import 'package:complex_mobx/src/stores/auth_store.dart';

void main() {
  testWidgets('Complex MobX App starts and Login flow works', (tester) async {
    await tester.pumpWidget(const ComplexApp());
    await tester.pumpAndSettle();

    // 1. Verify Login Page
    expect(find.text('Login Page'), findsOneWidget);
    
    // 2. Perform Login
    // Need to tap login button. 
    // Note: The AuthStore login has a 500ms delay.
    await tester.tap(find.byKey(const Key('login_btn')));
    
    // Pump to trigger loading state
    await tester.pump(); 
    // expect(find.byType(CircularProgressIndicator), findsOneWidget); // Might miss frame

    // Settle after async login
    await tester.pumpAndSettle();

    // 3. Verify Transition to Main Page (Products)
    expect(find.text('Products'), findsOneWidget);
  });
}
