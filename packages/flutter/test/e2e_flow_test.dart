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
  final AuthService auth;
  UserService(this.auth);
  String get username => auth.isLoggedIn ? 'User123' : 'Guest';
}

// --- Modules ---
class AuthModule extends Module {
  @override
  void binds(Binder i) {
    i.singleton<AuthService>(() => AuthService());
  }
  
  @override
  void exports(Binder i) {
    i.singleton<AuthService>(() => AuthService());
  }
}

class UserModule extends Module {
  @override
  List<Module> get imports => [AuthModule()];

  @override
  void binds(Binder i) {
    i.singleton<UserService>(() => UserService(i.get<AuthService>()));
  }
}

class FeatureModule extends Module {
  @override
  List<Type> get expects => [UserService];

  @override
  void binds(Binder i) {
    i.singleton<String>(() => 'Feature Data');
  }
}

// --- UI Components ---
class TestApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ModularityRoot(
      child: MaterialApp(
        navigatorObservers: [Modularity.observer],
        home: ModuleScope(
          module: UserModule(),
          child: const UserPage(),
        ),
      ),
    );
  }
}

class UserPage extends StatelessWidget {
  const UserPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final binder = ModuleProvider.of(context);
    final userService = binder.get<UserService>();
    
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
                      builder: (_) => ModuleScope(
                        module: FeatureModule(),
                        child: const FeaturePage(),
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
  const FeaturePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Wrap in try-catch to debug if resolving fails
    UserService? userService;
    try {
      userService = ModuleProvider.of(context).parent<UserService>();
    } catch (e) {
      return Scaffold(body: Text('Error: $e'));
    }
    
    return Scaffold(
      appBar: AppBar(title: const Text('Feature Page')),
      body: Center(
        child: SingleChildScrollView( // Fix Overflow in Feature Page too
          child: Text('User from Parent: ${userService.username}'),
        ),
      ),
    );
  }
}

void main() {
  testWidgets('E2E: Complex Flow (Imports -> Parents -> State Change)', (tester) async {
    // Set screen size to avoid overflow
    tester.view.physicalSize = const Size(400, 800);
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

    // Debug if text is not found
    if (find.text('Feature Page').evaluate().isEmpty) {
       debugDumpApp();
    }

    expect(find.text('Feature Page'), findsOneWidget);
    expect(find.text('User from Parent: User123'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.text('User: User123'), findsOneWidget);
  });
}
