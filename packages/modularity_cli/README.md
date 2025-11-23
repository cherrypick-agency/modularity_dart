# Modularity CLI

Command line tools for the Modularity framework. Currently provides dependency graph visualization.

## Features

- **Graph Visualization**: Generates an interactive dependency graph of your modules showing `imports` relationships.

## Installation

Add to your `dev_dependencies`:

```yaml
dev_dependencies:
  modularity_cli:
    path: packages/modularity_cli # or git dependency
```

## Usage

Create a script in your project (e.g., `tool/visualize_graph.dart`):

```dart
import 'package:modularity_cli/modularity_cli.dart';
import 'package:my_app/modules/app_module.dart';

void main() async {
  // Visualize starting from the root module
  await GraphVisualizer.visualize(AppModule());
}
```

Run it:

```bash
dart tool/visualize_graph.dart
```

**Note for Flutter projects**: If your modules import Flutter packages (e.g., widgets), run the script using `flutter test` to provide the necessary environment:

```bash
flutter test tool/visualize_graph.dart
```
(You might need to wrap `visualize` call in a `test` block or ensure the file name ends with `_test.dart` if strictly using test runner).

## How it works

1. Scans the `Module` structure recursively via `imports`.
2. Generates a DOT graph description.
3. Uses QuickChart API to render the graph.
4. Creates a temporary HTML file and opens it in your default browser.


