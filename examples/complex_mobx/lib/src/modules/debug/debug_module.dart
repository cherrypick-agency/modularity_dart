import 'package:flutter/material.dart';
import 'package:modularity_flutter/modularity_flutter.dart';

class DebugModule extends Module {
  static bool wasDisposed = false;

  @override
  void binds(Binder i) {}

  @override
  Future<void> onInit() async {
    wasDisposed = false;
  }

  @override
  void onDispose() {
    wasDisposed = true;
    print('DebugModule Disposed (Strict Strategy)!');
  }
}

class DebugWidget extends StatelessWidget {
  const DebugWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      color: Colors.amber[100],
      child: const Text('Debug Panel Active (Strict Disposal Check)'),
    );
  }
}
