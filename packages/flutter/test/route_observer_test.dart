import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modularity_flutter/modularity_flutter.dart';

class TestModule extends Module {
  bool isDisposed = false;
  bool isInitialized = false;

  @override
  void binds(Binder i) {}

  @override
  Future<void> onInit() async {
    isInitialized = true;
  }

  @override
  void onDispose() {
    isDisposed = true;
  }
}

final _observer = RouteObserver<ModalRoute<dynamic>>();

void main() {
  testWidgets('ModuleScope Retention Policy: Dispose only on Pop', (
    tester,
  ) async {
    final module = TestModule();

    await tester.pumpWidget(
      ModularityRoot(
        observer: _observer,
        child: MaterialApp(
          navigatorObservers: [_observer],
          home: Builder(
            builder: (context) => Scaffold(
              body: Column(
                children: [
                  const Text('Home'),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ModuleScope(
                            module: module,
                            child: const SecondPage(),
                          ),
                        ),
                      );
                    },
                    child: const Text('Push Module'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // 1. Initial State
    expect(module.isInitialized, false);
    expect(module.isDisposed, false);

    // 2. Push Module Screen
    await tester.tap(find.text('Push Module'));
    await tester.pumpAndSettle();

    expect(find.text('Module Screen Body'), findsOneWidget);
    expect(module.isInitialized, true);
    expect(module.isDisposed, false);

    // 3. Push Another Screen (Covering Module)
    await tester.tap(find.text('Push Next'));
    await tester.pumpAndSettle();

    expect(find.text('Third Screen Body'), findsOneWidget);
    expect(module.isDisposed, false);

    // 4. Pop Third Screen
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();

    expect(find.text('Module Screen Body'), findsOneWidget);
    expect(module.isDisposed, false);

    // 5. Pop Module Screen
    await tester.tap(find.text('Back to Home'));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(module.isDisposed, true);
  });
}

class SecondPage extends StatelessWidget {
  const SecondPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Module Screen')),
      body: Column(
        children: [
          const Text('Module Screen Body'),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ThirdPage()),
              );
            },
            child: const Text('Push Next'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Back to Home'),
          ),
        ],
      ),
    );
  }
}

class ThirdPage extends StatelessWidget {
  const ThirdPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Third Screen')),
      body: Column(
        children: [
          const Text('Third Screen Body'),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Back'),
          ),
        ],
      ),
    );
  }
}
