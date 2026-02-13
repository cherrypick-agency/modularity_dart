# CLI Tools

The `modularity_cli` package provides tools to analyze and visualize your module dependency graph without running the app. It introspects module registrations statically, detects configuration issues, and generates interactive HTML diagrams.

## What Is modularity_cli

Three components:

- **RecordingBinder** -- a `Binder` implementation that records registrations without instantiating dependencies.
- **ModuleBindingsAnalyzer** -- walks the module tree using `RecordingBinder` and produces `ModuleBindingsSnapshot` for each module.
- **GraphVisualizer** -- generates HTML visualizations (Graphviz DOT or interactive AntV G6) and opens them in the browser.

## Installation

Add `modularity_cli` as a dev dependency:

```yaml
dev_dependencies:
  modularity_cli: ^0.1.0
```

## RecordingBinder

`RecordingBinder` implements `ExportableBinder` and tracks every `registerLazySingleton`, `registerFactory`, and `registerSingleton` call as a `DependencyRecord` without creating real instances.

```dart
import 'package:modularity_cli/modularity_cli.dart';

final binder = RecordingBinder();
myModule.binds(binder);

for (final dep in binder.privateDependencies) {
  print('${dep.type} [${dep.kind.label}]');
}
```

Each `DependencyRecord` has:
- `type` -- the registered `Type`.
- `kind` -- `DependencyRegistrationKind.singleton`, `.factory`, or `.instance`.
- `displayName` -- formatted string like `AuthService [singleton]`.

Key behaviors:
- `get<T>()` throws `ModuleConfigurationException` -- you cannot resolve dependencies during analysis.
- `tryGet<T>()` returns `null`.
- Duplicate exports throw `ModuleConfigurationException`, matching the runtime behavior.
- Private registrations of the same type replace the previous record.

## ModuleBindingsAnalyzer

`ModuleBindingsAnalyzer` recursively walks a module tree. For each module, it:

1. Analyzes imported modules first (depth-first).
2. Creates a `RecordingBinder` with imported binders.
3. Calls `module.binds(binder)` and `module.exports(binder)`.
4. Produces a `ModuleBindingsSnapshot`.

```dart
import 'package:modularity_cli/modularity_cli.dart';

final analyzer = ModuleBindingsAnalyzer();
final snapshot = analyzer.analyze(AppModule());

print('Module: ${snapshot.moduleType}');
print('Private: ${snapshot.privateDependencies.length}');
print('Public: ${snapshot.publicDependencies.length}');
print('Expects: ${snapshot.expects}');
print('Warnings: ${snapshot.warnings}');
```

`ModuleBindingsSnapshot` fields:

| Field | Type | Description |
|-------|------|-------------|
| `moduleType` | `Type` | Runtime type of the analyzed module |
| `privateDependencies` | `List<DependencyRecord>` | Dependencies registered in `binds()` |
| `publicDependencies` | `List<DependencyRecord>` | Dependencies registered in `exports()` |
| `expects` | `List<Type>` | Types declared in `Module.expects` |
| `warnings` | `List<String>` | Errors caught during analysis (non-fatal) |

The analyzer caches results by module runtime type, so analyzing the same module tree twice is cheap.

### Circular dependency detection

If the module import graph has a cycle, `analyze()` throws `CircularDependencyException` with the full chain:

```
CircularDependencyException: Circular module imports detected: ModuleA -> ModuleB -> ModuleA
```

### Phase failure handling

If `binds()` or `exports()` throws (e.g. calling `binder.get<T>()` during analysis), the error is caught and added to `warnings`. Analysis continues with partial results.

## GraphVisualizer

`GraphVisualizer` generates dependency graph visualizations and opens them in the default browser.

### Basic usage

```dart
import 'package:modularity_cli/modularity_cli.dart';

void main() async {
  await GraphVisualizer.visualize(AppModule());
}
```

This generates a Graphviz DOT diagram rendered via quickchart.io and opens it in the browser.

### Renderers

Two renderers are available via `GraphRenderer`:

```dart
// Static Graphviz DOT diagram (default)
await GraphVisualizer.visualize(
  AppModule(),
  renderer: GraphRenderer.graphviz,
);

// Interactive AntV G6 diagram with drag, zoom, and tooltips
await GraphVisualizer.visualize(
  AppModule(),
  renderer: GraphRenderer.g6,
);
```

| Renderer | Description |
|----------|-------------|
| `GraphRenderer.graphviz` | Static DOT diagram rendered via quickchart.io. Shows module hierarchy, registrations, and edges. |
| `GraphRenderer.g6` | Interactive HTML with AntV G6. Supports drag, zoom, tooltips showing registrations and expects. |

### What the graph shows

Each module node displays:
- Module name (bold).
- **Public** dependencies (exported via `exports()`).
- **Private** dependencies (registered via `binds()`).
- **Expects** (types required from parent scopes, highlighted in amber).
- **Warnings** (analysis failures, highlighted in red).

Edges show two relationship types:
- **imports** (dashed line) -- the source module imports the target.
- **owns** (diamond arrow) -- the source module declares the target as a `submodule`.

### Running analysis from a script

Create a standalone Dart script in your project:

```dart
// tool/visualize.dart
import 'package:modularity_cli/modularity_cli.dart';
import 'package:my_app/modules/app_module.dart';

void main() async {
  await GraphVisualizer.visualize(
    AppModule(),
    renderer: GraphRenderer.g6,
  );
}
```

Run it:

```bash
dart run tool/visualize.dart
```

### Programmatic graph data

For custom analysis or CI integration, build graph data without opening the browser:

```dart
import 'package:modularity_cli/modularity_cli.dart';

final graphData = GraphVisualizer.buildGraphData(AppModule());

for (final node in graphData.nodes) {
  print('${node.name}: ${node.publicDependencies.length} exports, '
      '${node.privateDependencies.length} private');
}

for (final edge in graphData.edges) {
  print('${edge.source} --${edge.type.name}--> ${edge.target}');
}
```

`ModuleGraphData` contains:
- `nodes` -- `List<ModuleNode>` with id, name, dependencies, expects, warnings.
- `edges` -- `List<ModuleEdge>` with source, target, and type (`imports` or `owns`).

Both `ModuleGraphData` and its children have `toJson()` methods for serialization.

### DOT output

For pipelines that consume Graphviz DOT directly:

```dart
final dot = GraphVisualizer.generateDot(AppModule());
print(dot);
```

Output is a valid Graphviz DOT string that can be rendered by any Graphviz-compatible tool.

## CI Integration

Use the analyzer programmatically to enforce architectural rules in CI:

```dart
// test/architecture_test.dart
import 'package:modularity_cli/modularity_cli.dart';
import 'package:my_app/modules/app_module.dart';
import 'package:test/test.dart';

void main() {
  test('no circular dependencies', () {
    final analyzer = ModuleBindingsAnalyzer();
    // analyze() throws CircularDependencyException if cycles exist
    expect(() => analyzer.analyze(AppModule()), returnsNormally);
  });

  test('all modules have exports', () {
    final analyzer = ModuleBindingsAnalyzer();
    final snapshot = analyzer.analyze(AppModule());
    expect(snapshot.publicDependencies, isNotEmpty,
        reason: 'AppModule should export at least one dependency');
  });

  test('no analysis warnings', () {
    final analyzer = ModuleBindingsAnalyzer();
    final snapshot = analyzer.analyze(AppModule());
    expect(snapshot.warnings, isEmpty,
        reason: 'Module analysis should complete without warnings');
  });
}
```

Run as part of your test suite:

```bash
dart test test/architecture_test.dart
```

### Analyzing the full module tree

To check all modules in the tree, not just the root:

```dart
test('all modules in tree are warning-free', () {
  final graphData = GraphVisualizer.buildGraphData(AppModule());

  for (final node in graphData.nodes) {
    expect(node.warnings, isEmpty,
        reason: '${node.name} has analysis warnings');
  }
});
```

## Reading the Output

### Graph node anatomy

```
+---------------------------+
|        AuthModule         |  <- Module name
+---------------------------+
| Public                    |
|  - AuthService [singleton]|  <- Exported dependency
+---------------------------+
| Private                   |
|  - AuthRepository [singleton]|  <- Internal dependency
|  - LoginUseCase [factory]    |
+---------------------------+
| Expects                   |
|  - ApiClient              |  <- Required from parent
+---------------------------+
```

### Edge types

- **imports** (dashed): `AuthModule --imports--> NetworkModule` means AuthModule lists NetworkModule in its `imports` getter. AuthModule can resolve NetworkModule's public exports.
- **owns** (diamond): `AppModule --owns--> AuthModule` means AppModule lists AuthModule in its `submodules` getter. This is for visualization only -- submodules are not initialized by the parent.

### Interpreting warnings

Warnings appear when `binds()` or `exports()` fails during analysis. Common causes:

- Calling `binder.get<T>()` in `binds()` to resolve a dependency that doesn't exist yet in the recording context.
- Side effects in constructors that fail without a running app.

Warnings don't prevent visualization -- the module is shown with partial data and a red warning indicator.
