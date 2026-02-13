import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modularity_flutter/modularity_flutter.dart';

// --- Mock Domain Services ---
class AuthService {
  bool isLoggedIn = false;
  void login() => isLoggedIn = true;
  void logout() => isLoggedIn = false;
}

class UserService {
  UserService(this.auth);
  final AuthService auth;
  String get username => auth.isLoggedIn ? 'User123' : 'Guest';
}

// --- Modules ---
class AuthModule extends Module {
  @override
  void binds(Binder i) {
    i.registerLazySingleton<AuthService>(() => AuthService());
  }

  @override
  void exports(Binder i) {
    i.registerLazySingleton<AuthService>(() => AuthService());
  }
}

class UserModule extends Module {
  @override
  List<Module> get imports => [AuthModule()];

  @override
  void binds(Binder i) {
    i.registerLazySingleton<UserService>(
      () => UserService(i.get<AuthService>()),
    );
  }
}

class FeatureModule extends Module {
  @override
  List<Type> get expects => [UserService];

  @override
  void binds(Binder i) {
    i.registerLazySingleton<String>(() => 'Feature Data');
  }
}

// --- UI Components ---
final _observer = RouteObserver<ModalRoute<dynamic>>();

class TestApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ModularityRoot(
      observer: _observer,
      child: MaterialApp(
        navigatorObservers: [_observer],
        home: ModuleScope(module: UserModule(), child: const UserPage()),
      ),
    );
  }
}

class UserPage extends StatelessWidget {
  const UserPage({super.key});

  @override
  Widget build(BuildContext context) {
    final binder = ModuleProvider.of(context);
    final userService = binder.get<UserService>();

    // Capture the controller to pass it to the next route
    final parentProvider = context
        .dependOnInheritedWidgetOfExactType<ModuleProvider>();
    final parentController = parentProvider?.controller;

    return Scaffold(
      appBar: AppBar(title: Text('User: ${userService.username}')),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                onPressed: () {
                  binder.get<AuthService>().login();
                  (context as Element).markNeedsBuild();
                },
                child: const Text('Login'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ModuleProvider(
                        controller: parentController!,
                        child: ModuleScope(
                          module: FeatureModule(),
                          child: const FeaturePage(),
                        ),
                      ),
                    ),
                  );
                },
                child: const Text('Open Feature'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FeaturePage extends StatelessWidget {
  const FeaturePage({super.key});

  @override
  Widget build(BuildContext context) {
    UserService? userService;
    try {
      userService = ModuleProvider.of(context).parent<UserService>();
    } catch (e) {
      return Scaffold(body: Text('Error: $e'));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Feature Page')),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Feature Page Body'),
              Text('User from Parent: ${userService.username}'),
            ],
          ),
        ),
      ),
    );
  }
}

void main() {
  testWidgets('E2E: Complex Flow (Imports -> Parents -> State Change)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(TestApp());
    await tester.pumpAndSettle();

    expect(find.text('User: Guest'), findsOneWidget);

    await tester.tap(find.text('Login'));
    await tester.pump();
    expect(find.text('User: User123'), findsOneWidget);

    await tester.tap(find.text('Open Feature'));
    await tester.pumpAndSettle();

    if (find.text('Module Init Failed').evaluate().isNotEmpty) {
      debugDumpApp();
      fail('Module Init Failed. See logs for details.');
    }

    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Feature Page'),
      ),
      findsOneWidget,
    );

    expect(find.text('Feature Page Body'), findsOneWidget);

    expect(find.text('User from Parent: User123'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.text('User: User123'), findsOneWidget);
  });
}
