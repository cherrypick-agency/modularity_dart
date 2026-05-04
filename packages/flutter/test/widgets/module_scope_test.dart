import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modularity_flutter/modularity_flutter.dart';

class ConfigurableScopeModule extends Module implements Configurable<String> {
  ConfigurableScopeModule(this.name);

  final String name;
  String? configuredArg;
  int initCount = 0;
  int disposeCount = 0;

  @override
  void configure(String args) {
    configuredArg = args;
  }

  @override
  void binds(Binder i) {
    i.registerFactory<String>(() => configuredArg ?? 'missing');
  }

  @override
  Future<void> onInit() async {
    initCount++;
  }

  @override
  Future<void> onDispose() async {
    disposeCount++;
  }
}

Widget _wrapScope({
  required ConfigurableScopeModule module,
  required String args,
  required RouteObserver<ModalRoute<dynamic>> observer,
  ModuleRetentionPolicy retentionPolicy = ModuleRetentionPolicy.routeBound,
  Object? retentionKey,
  Map<String, Object?>? retentionExtras,
}) {
  return ModularityRoot(
    observer: observer,
    child: MaterialApp(
      navigatorObservers: [observer],
      home: ModuleScope<ConfigurableScopeModule>(
        module: module,
        args: args,
        retentionPolicy: retentionPolicy,
        retentionKey: retentionKey,
        retentionExtras: retentionExtras,
        child: const SizedBox.shrink(),
      ),
    ),
  );
}

void main() {
  group('ModuleScope widget updates', () {
    testWidgets('restarts controller when args change', (tester) async {
      final observer = RouteObserver<ModalRoute<dynamic>>();
      final first = ConfigurableScopeModule('first');
      final second = ConfigurableScopeModule('second');

      await tester.pumpWidget(
        _wrapScope(module: first, args: 'one', observer: observer),
      );
      await tester.pumpAndSettle();

      expect(first.configuredArg, 'one');
      expect(first.initCount, 1);
      expect(first.disposeCount, 0);

      await tester.pumpWidget(
        _wrapScope(module: second, args: 'two', observer: observer),
      );
      await tester.pumpAndSettle();

      expect(first.disposeCount, 1);
      expect(second.configuredArg, 'two');
      expect(second.initCount, 1);
    });

    testWidgets('restarts controller when derived retention key changes', (
      tester,
    ) async {
      final observer = RouteObserver<ModalRoute<dynamic>>();
      final first = ConfigurableScopeModule('first');
      final second = ConfigurableScopeModule('second');

      await tester.pumpWidget(
        _wrapScope(
          module: first,
          args: 'same',
          observer: observer,
          retentionExtras: {'tenant': 'a'},
        ),
      );
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        _wrapScope(
          module: second,
          args: 'same',
          observer: observer,
          retentionExtras: {'tenant': 'b'},
        ),
      );
      await tester.pumpAndSettle();

      expect(first.disposeCount, 1);
      expect(second.configuredArg, 'same');
      expect(second.initCount, 1);
    });
  });
}
