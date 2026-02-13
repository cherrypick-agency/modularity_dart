import 'dart:io';
import 'package:path/path.dart' as path;

/// Writes HTML content to a temporary file and opens it in the default browser.
///
/// Supports macOS (`open`), Windows (`cmd /c start`), and Linux (`xdg-open`).
/// Used internally by [GraphVisualizer] after generating the HTML output.
class BrowserOpener {
  /// Write [htmlContent] to a temporary file and launch the platform's
  /// default browser to display it.
  static Future<void> openHtml(String htmlContent) async {
    final tempDir = Directory.systemTemp.createTempSync('modularity_graph_');
    final file = File(path.join(tempDir.path, 'graph.html'));

    await file.writeAsString(htmlContent);

    final filePath = file.absolute.path;
    print('Graph generated at: $filePath');

    if (Platform.isMacOS) {
      await Process.run('open', [filePath]);
    } else if (Platform.isWindows) {
      await Process.run('cmd', ['/c', 'start', '', filePath]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [filePath]);
    } else {
      print(
        'Could not open browser automatically. Please open the file manually.',
      );
    }
  }
}
