class HtmlGenerator {
  static String generate(String dotContent) {
    // Encode the DOT content for URL
    final encodedDot = Uri.encodeComponent(dotContent);
    final url = 'https://quickchart.io/graphviz?graph=$encodedDot';

    return '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Modularity Graph</title>
    <style>
        body, html { margin: 0; padding: 0; height: 100%; display: flex; justify-content: center; align-items: center; background-color: #f5f5f5; }
        img { max-width: 95%; max-height: 95%; box-shadow: 0 4px 8px rgba(0,0,0,0.1); background: white; padding: 20px; border-radius: 8px; }
        .error { color: red; padding: 20px; }
    </style>
</head>
<body>
    <img src="$url" alt="Module Dependency Graph" onerror="this.style.display='none'; document.getElementById('err').style.display='block';">
    <div id="err" class="error" style="display:none;">
        <h3>Error loading graph</h3>
        <p>Could not load the graph image. Check your internet connection.</p>
        <details>
            <summary>DOT Source</summary>
            <pre>${dotContent.replaceAll('<', '&lt;')}</pre>
        </details>
    </div>
</body>
</html>
''';
  }
}
