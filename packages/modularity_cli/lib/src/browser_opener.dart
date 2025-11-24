import 'dart:io';
import 'package:path/path.dart' as path;

class BrowserOpener {
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
          'Could not open browser automatically. Please open the file manually.');
    }
  }
}
