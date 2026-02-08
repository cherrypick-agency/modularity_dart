import 'package:modularity_core/modularity_core.dart';
import 'package:test/test.dart';

// Dummy types used as map keys in children
class ModuleA extends Module {
  @override
  void binds(Binder i) {}
}

class ModuleB extends Module {
  @override
  void binds(Binder i) {}
}

class ModuleC extends Module {
  @override
  void binds(Binder i) {}
}

void main() {
  group('ModuleOverrideScope', () {
    group('childFor()', () {
      test('returns child scope for matching type', () {
        final childScope = ModuleOverrideScope(
          selfOverrides: (binder) {
            binder.registerSingleton<String>('overridden');
          },
        );
        final scope = ModuleOverrideScope(children: {ModuleA: childScope});

        expect(scope.childFor(ModuleA), same(childScope));
      });

      test('returns null for non-existing type', () {
        final scope = ModuleOverrideScope(
          children: {ModuleA: const ModuleOverrideScope()},
        );

        expect(scope.childFor(ModuleB), isNull);
      });

      test('returns null when children map is empty', () {
        const scope = ModuleOverrideScope();
        expect(scope.childFor(ModuleA), isNull);
      });

      test('handles multiple children correctly', () {
        final scopeA = ModuleOverrideScope(
          selfOverrides: (binder) {
            binder.registerSingleton<String>('a');
          },
        );
        final scopeB = ModuleOverrideScope(
          selfOverrides: (binder) {
            binder.registerSingleton<String>('b');
          },
        );

        final scope = ModuleOverrideScope(
          children: {ModuleA: scopeA, ModuleB: scopeB},
        );

        expect(scope.childFor(ModuleA), same(scopeA));
        expect(scope.childFor(ModuleB), same(scopeB));
      });
    });

    group('withAdditionalOverride()', () {
      test('combines current and new overrides', () {
        final binder = SimpleBinder();
        final scope = ModuleOverrideScope(
          selfOverrides: (b) {
            b.registerSingleton<String>('original');
          },
        );

        final combined = scope.withAdditionalOverride((b) {
          b.registerSingleton<int>(42);
        });

        // Apply combined overrides to a binder
        combined.selfOverrides!(binder);

        expect(binder.get<String>(), equals('original'));
        expect(binder.get<int>(), equals(42));
      });

      test('preserves children from original scope', () {
        final childScope = const ModuleOverrideScope();
        final scope = ModuleOverrideScope(
          children: {ModuleA: childScope},
          selfOverrides: (b) {},
        );

        final combined = scope.withAdditionalOverride((b) {});

        expect(combined.children[ModuleA], same(childScope));
      });

      test(
        'returns scope with just the new override when original is null',
        () {
          const scope = ModuleOverrideScope();
          var called = false;

          final combined = scope.withAdditionalOverride((b) {
            called = true;
          });

          final binder = SimpleBinder();
          combined.selfOverrides!(binder);
          expect(called, isTrue);
        },
      );

      test(
        'returns scope with original override when new override is null',
        () {
          var called = false;
          final scope = ModuleOverrideScope(
            selfOverrides: (b) {
              called = true;
            },
          );

          final combined = scope.withAdditionalOverride(null);

          final binder = SimpleBinder();
          combined.selfOverrides!(binder);
          expect(called, isTrue);
        },
      );

      test('returns scope with null selfOverrides when both are null', () {
        const scope = ModuleOverrideScope();
        final combined = scope.withAdditionalOverride(null);
        expect(combined.selfOverrides, isNull);
      });

      test('applies overrides in order: original first, then additional', () {
        final order = <String>[];
        final scope = ModuleOverrideScope(
          selfOverrides: (b) {
            order.add('first');
          },
        );

        final combined = scope.withAdditionalOverride((b) {
          order.add('second');
        });

        final binder = SimpleBinder();
        combined.selfOverrides!(binder);
        expect(order, equals(['first', 'second']));
      });
    });

    group('merge()', () {
      test('returns this when merging with null', () {
        final scope = ModuleOverrideScope(
          selfOverrides: (b) {},
          children: {ModuleA: const ModuleOverrideScope()},
        );

        final merged = scope.merge(null);
        expect(merged.children[ModuleA], same(scope.children[ModuleA]));
      });

      test('combines selfOverrides from both scopes', () {
        final binder = SimpleBinder();
        final scope1 = ModuleOverrideScope(
          selfOverrides: (b) {
            b.registerSingleton<String>('from scope1');
          },
        );
        final scope2 = ModuleOverrideScope(
          selfOverrides: (b) {
            b.registerSingleton<int>(42);
          },
        );

        final merged = scope1.merge(scope2);
        merged.selfOverrides!(binder);

        expect(binder.get<String>(), equals('from scope1'));
        expect(binder.get<int>(), equals(42));
      });

      test('merges disjoint children maps', () {
        final scope1 = ModuleOverrideScope(
          children: {ModuleA: const ModuleOverrideScope()},
        );
        final scope2 = ModuleOverrideScope(
          children: {ModuleB: const ModuleOverrideScope()},
        );

        final merged = scope1.merge(scope2);

        expect(merged.children, hasLength(2));
        expect(merged.children.containsKey(ModuleA), isTrue);
        expect(merged.children.containsKey(ModuleB), isTrue);
      });

      test('recursively merges overlapping children', () {
        final scope1 = ModuleOverrideScope(
          children: {
            ModuleA: ModuleOverrideScope(
              selfOverrides: (b) {
                b.registerSingleton<String>('from scope1 child');
              },
            ),
          },
        );
        final scope2 = ModuleOverrideScope(
          children: {
            ModuleA: ModuleOverrideScope(
              selfOverrides: (b) {
                b.registerSingleton<int>(99);
              },
            ),
          },
        );

        final merged = scope1.merge(scope2);
        final mergedChild = merged.children[ModuleA]!;

        final binder = SimpleBinder();
        mergedChild.selfOverrides!(binder);

        expect(binder.get<String>(), equals('from scope1 child'));
        expect(binder.get<int>(), equals(99));
      });

      test('applies selfOverrides in order: current first, then other', () {
        final order = <String>[];
        final scope1 = ModuleOverrideScope(
          selfOverrides: (b) {
            order.add('scope1');
          },
        );
        final scope2 = ModuleOverrideScope(
          selfOverrides: (b) {
            order.add('scope2');
          },
        );

        final merged = scope1.merge(scope2);
        final binder = SimpleBinder();
        merged.selfOverrides!(binder);

        expect(order, equals(['scope1', 'scope2']));
      });

      test('merges with scope that has null selfOverrides', () {
        final scope1 = ModuleOverrideScope(
          selfOverrides: (b) {
            b.registerSingleton<String>('value');
          },
        );
        const scope2 = ModuleOverrideScope();

        final merged = scope1.merge(scope2);
        final binder = SimpleBinder();
        merged.selfOverrides!(binder);

        expect(binder.get<String>(), equals('value'));
      });

      test('handles both having null selfOverrides', () {
        const scope1 = ModuleOverrideScope(
          children: {ModuleA: ModuleOverrideScope()},
        );
        const scope2 = ModuleOverrideScope(
          children: {ModuleB: ModuleOverrideScope()},
        );

        final merged = scope1.merge(scope2);
        expect(merged.selfOverrides, isNull);
        expect(merged.children, hasLength(2));
      });

      test('preserves non-overlapping children from both sides', () {
        const scope1 = ModuleOverrideScope(
          children: {
            ModuleA: ModuleOverrideScope(),
            ModuleB: ModuleOverrideScope(),
          },
        );
        const scope2 = ModuleOverrideScope(
          children: {
            ModuleB: ModuleOverrideScope(),
            ModuleC: ModuleOverrideScope(),
          },
        );

        final merged = scope1.merge(scope2);
        expect(merged.children, hasLength(3));
        expect(merged.children.containsKey(ModuleA), isTrue);
        expect(merged.children.containsKey(ModuleB), isTrue);
        expect(merged.children.containsKey(ModuleC), isTrue);
      });
    });

    group('constructor defaults', () {
      test('selfOverrides defaults to null', () {
        const scope = ModuleOverrideScope();
        expect(scope.selfOverrides, isNull);
      });

      test('children defaults to empty map', () {
        const scope = ModuleOverrideScope();
        expect(scope.children, isEmpty);
      });
    });
  });
}
