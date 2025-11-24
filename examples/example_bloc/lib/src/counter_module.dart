import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:modularity_flutter/modularity_flutter.dart';
import 'counter_cubit.dart';

class CounterModule extends Module {
  @override
  void binds(Binder i) {
    // 1. Register Cubit as Factory or Singleton in Binder
    i.factory<CounterCubit>(() => CounterCubit());
  }
}

class CounterPage extends StatelessWidget {
  const CounterPage({super.key});

  @override
  Widget build(BuildContext context) {
    // 2. Provide Cubit using BlocProvider, resolving it from ModuleProvider
    return BlocProvider(
      create: (context) =>
          ModuleProvider.of(context, listen: false).get<CounterCubit>(),
      child: const _CounterView(),
    );
  }
}

class _CounterView extends StatelessWidget {
  const _CounterView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bloc Example')),
      body: Center(
        child: BlocBuilder<CounterCubit, int>(
          builder: (context, count) {
            return Text('Count: $count',
                style: Theme.of(context).textTheme.headlineMedium);
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.read<CounterCubit>().increment(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
