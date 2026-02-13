/// Testing utilities for the Modularity dependency injection framework.
///
/// Provides helpers to verify module lifecycle, inspect dependency
/// registrations, and assert resolution behavior without requiring Flutter
/// widgets.
///
/// ## Quick Start
///
/// ```dart
/// import 'package:modularity_test/modularity_test.dart';
/// import 'package:test/test.dart';
///
/// void main() {
///   test('AuthModule registers AuthService', () async {
///     await testModule(AuthModule(), (module, binder) {
///       expect(binder.hasSingleton<AuthService>(), isTrue);
///       expect(binder.get<AuthService>(), isNotNull);
///     });
///   });
/// }
/// ```
///
/// ## Key APIs
///
/// - [testModule] -- initializes a module in isolation and runs assertions.
/// - [TestBinder] -- proxy binder that records all registrations and lookups.
library modularity_test;

export 'src/module_test.dart';
export 'src/test_binder.dart';
