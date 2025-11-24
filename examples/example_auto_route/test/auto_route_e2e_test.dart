import 'package:example_auto_route/main.dart';
import 'package:example_auto_route/modules/auth/auth_module.dart';
import 'package:example_auto_route/modules/dashboard/dashboard_module.dart';
import 'package:example_auto_route/modules/details/details_module.dart';
import 'package:example_auto_route/modules/home/home_module.dart';
import 'package:example_auto_route/modules/settings/settings_module.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modularity_flutter/modularity_flutter.dart';

void main() {
  testWidgets(
      'AutoRoute E2E Flow: Login -> Home -> Details -> Settings -> Logout',
      (WidgetTester tester) async {
    // 1. Start App
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // Verify we are at Login Page (redirected by Guard)
    expect(find.byType(AuthPage), findsOneWidget);
    expect(find.widgetWithText(AppBar, 'Login'), findsOneWidget);

    // 2. Perform Login
    await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
    await tester.pumpAndSettle();

    // Verify we are at Dashboard -> Home
    expect(find.byType(DashboardPage), findsOneWidget);
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.text('Item 0'), findsOneWidget);

    // 3. Navigate to Details
    await tester.tap(find.text('Item 1'));
    await tester.pumpAndSettle();

    // Verify Details Page
    expect(find.byType(DetailsPage), findsOneWidget);
    expect(find.text('Details 1'), findsOneWidget);
    expect(find.text('AuthService is available here too!'), findsOneWidget);

    // 4. Go Back
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    // Verify back at Home
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byType(DetailsPage), findsNothing);

    // 5. Navigate to Settings (via BottomNavBar)
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();

    // Verify Settings Page
    expect(find.byType(SettingsPage), findsOneWidget);

    // 6. Logout
    await tester.tap(find.text('Logout'));
    await tester.pumpAndSettle();

    // Verify redirected to Login
    expect(find.byType(AuthPage), findsOneWidget);
  });
}
