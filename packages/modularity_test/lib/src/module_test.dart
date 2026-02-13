import 'dart:async';
import 'package:modularity_core/modularity_core.dart';
import 'test_binder.dart';

/// Test helper that initializes a [Module] in isolation, runs the [body]
/// callback, and disposes the controller afterward.
///
/// Creates a [SimpleBinder] wrapped in a [TestBinder], initializes the
/// module's full lifecycle (binds, imports, exports), and passes both the
/// module instance and the test binder to the callback for assertions.
///
/// Optionally accepts [overrides] and [overrideScope] to test DI overrides.
///
/// ## Example
///
/// ```dart
/// await testModule(
///   MyModule(),
///   (module, binder) async {
///     expect(binder.get<MyService>(), isNotNull);
///     expect(binder.hasSingleton<MyService>(), isTrue);
///   },
/// );
/// ```
///
/// See also:
/// - [TestBinder] for inspecting registration and resolution history.
Future<void> testModule<T extends Module>(
  T module,
  FutureOr<void> Function(T module, TestBinder binder) body, {
  void Function(Binder)? overrides,
  ModuleOverrideScope? overrideScope,
}) async {
  // Create a real binder and wrap it with TestBinder
  final factory = SimpleBinderFactory();
  final realBinder = factory.create();
  final testBinder = TestBinder(realBinder);

  final controller = ModuleController(
    module,
    binder: testBinder, // Inject TestBinder
    overrides: overrides,
    overrideScopeTree: overrideScope,
  );

  try {
    await controller.initialize(<ModuleRegistryKey, ModuleController>{});
    await body(module, testBinder);
  } finally {
    await controller.dispose();
  }
}
