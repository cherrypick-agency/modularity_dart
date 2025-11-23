import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modularity_flutter/modularity_flutter.dart';
import 'providers.dart';

class CounterModule extends Module {
  @override
  void binds(Binder i) {
    // Modularity just manages Lifecycle/Navigation here.
    // Riverpod manages state.
    // BUT: We can inject Modularity dependencies INTO Riverpod.
    i.singleton<AuthService>(() => AuthService('secret-token'));
  }
}

class CounterPage extends StatelessWidget {
  const CounterPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Resolve dependency from Modularity
    // ModuleProvider.of(context) returns Binder.
    // We use .get<T>() on the binder.
    final binder = ModuleProvider.of(context);
    final authService = binder.get<AuthService>();

    return ProviderScope(
      overrides: [
        // Inject Modularity dependency into Riverpod
        authServiceProvider.overrideWithValue(authService),
      ],
      child: const _CounterView(),
    );
  }
}

class _CounterView extends ConsumerWidget {
  const _CounterView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(counterProvider);
    final auth = ref.watch(authServiceProvider);

    return Scaffold(
      appBar: AppBar(title: Text('Riverpod: ${auth.token}')),
      body: Center(
        child: Text('Count: $count', style: Theme.of(context).textTheme.headlineMedium),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => ref.read(counterProvider.notifier).state++,
        child: const Icon(Icons.add),
      ),
    );
  }
}
