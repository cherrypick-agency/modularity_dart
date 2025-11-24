import 'package:complex_app/modules/home/home_module.dart';
import 'package:modularity_cli/modularity_cli.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Generate Dependency Graph (complex_app)', () async {
    print('Generating dependency graph for HomeModule (complex_app)...');
    await GraphVisualizer.visualize(HomeModule());
  });
}
