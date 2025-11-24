import 'package:example_go_router/main.dart';
import 'package:example_go_router/modules/auth/auth_module.dart';
import 'package:example_go_router/modules/dashboard/dashboard_module.dart';
import 'package:example_go_router/modules/details/details_module.dart';
import 'package:example_go_router/modules/home/home_module.dart';
import 'package:example_go_router/modules/settings/settings_module.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'GoRouter E2E Flow: Login -> Home -> Details -> Settings -> Logout',
      (WidgetTester tester) async {
    // 1. Start App
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // Verify we are at Login Page (redirected from /home because not logged in)
    expect(find.byType(AuthPage), findsOneWidget);
    expect(find.widgetWithText(AppBar, 'Login'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Login'), findsOneWidget);

    // Verify AuthModule is active
    // Note: Finder by type for ModuleScope might return multiple if we don't distinguish.
    // But AuthPage is child of ModuleScope(AuthModule), so valid.

    // 2. Perform Login
    await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
    await tester.pumpAndSettle();

    // Verify we are at Home Page (ShellRoute -> Home)
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byType(DashboardPage), findsOneWidget);
    expect(find.text('Item 0'), findsOneWidget);

    // Verify RootModule, DashboardModule, HomeModule are active
    // Just checking widgets is enough to imply modules are likely initialized,
    // but strictly we can check binding if we wanted (not easy from widget test without key).

    // 3. Navigate to Details
    await tester.tap(find.text('Item 1'));
    await tester.pumpAndSettle();

    // Verify Details Page
    expect(find.byType(DetailsPage), findsOneWidget);
    expect(find.text('Details 1'), findsOneWidget);
    expect(find.text('AuthService is available here too!'), findsOneWidget);

    // Verify DetailsModule expects AuthService -> Should not throw

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
