import 'dart:async';
import 'package:modularity_contracts/modularity_contracts.dart';
import 'package:modularity_core/modularity_core.dart';
import 'test_binder.dart';

/// Test helper to verify module lifecycle.
/// 
/// Example:
/// ```dart
/// await testModule(
///   MyModule(),
///   (module, binder) async {
///     expect(binder.get<MyService>(), isNotNull);
///     expect(binder.hasSingleton<MyService>(), isTrue);
///   }
/// );
/// ```
Future<void> testModule<T extends Module>(
  T module,
  FutureOr<void> Function(T module, TestBinder binder) body, {
  void Function(Binder)? overrides,
}) async {
  // Create a real binder and wrap it with TestBinder
  final factory = SimpleBinderFactory();
  final realBinder = factory.create();
  final testBinder = TestBinder(realBinder);

  final controller = ModuleController(
    module, 
    binder: testBinder, // Inject TestBinder
    overrides: overrides
  );
  
  try {
    await controller.initialize({});
    await body(module, testBinder);
  } finally {
    await controller.dispose();
  }
}
