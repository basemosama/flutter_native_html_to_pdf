import '../models/pdf_options.dart';

/// Utilities for preparing HTML content for PDF conversion.
///
/// These helpers add print-friendly CSS rules that native platform print
/// engines (Android `PrintDocumentAdapter`, iOS `UIPrintPageRenderer`)
/// respect — such as `page-break-inside: avoid` for tables, font loading,
/// and text direction support.
///
/// Usage is **optional** — the converter renders whatever HTML it receives.
/// Use these when you want better pagination and font handling without
/// writing the CSS yourself.
///
/// You can either call [wrapHtml] manually, or set [PdfOptions.wrapOptions]
/// to have the converter apply it automatically.
class HtmlPdfHelper {
  HtmlPdfHelper._();

  /// Wraps [html] with a full HTML document structure containing
  /// print-friendly CSS and proper font/direction setup.
  ///
  /// If [html] already contains an `<html>` tag, the metadata is injected
  /// into the existing structure instead of wrapping it.
  static String wrapHtml(
    String html, {
    HtmlWrapOptions options = const HtmlWrapOptions(),
  }) {
    final dir = options.direction == PdfTextDirection.rtl ? 'rtl' : 'ltr';
    final lang = options.language;
    final fontFamily = options.fontFamily ?? 'system-ui, sans-serif';
    final googleFonts = options.googleFonts;
    final bg = options.backgroundColor ?? 'white';

    if (RegExp(r'<html\b[^>]*>', caseSensitive: false).hasMatch(html)) {
      return _injectMetadata(
        html,
        dir: dir,
        lang: lang,
        fontFamily: fontFamily,
        googleFonts: googleFonts,
        avoidBreakInsideSelectors: options.avoidBreakInsideSelectors,
        backgroundColor: bg,
      );
    }

    final fontLinks = _buildGoogleFontLinks(googleFonts);
    final breakCss = _buildBreakInsideCss(options.avoidBreakInsideSelectors);

    return '''
<!DOCTYPE html>
<html dir="$dir" lang="$lang">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
$fontLinks  <style>
    @page { size: A4; margin: 12mm; }
    html, body {
      margin: 0;
      padding: 0;
      background: $bg;
      font-family: $fontFamily;
      direction: $dir;
    }
    table {
      width: 100%;
      border-collapse: collapse;
      page-break-inside: avoid;
      break-inside: avoid;
    }
    tr {
      page-break-inside: avoid;
      break-inside: avoid;
    }
    thead { display: table-header-group; }
    tfoot { display: table-footer-group; }
    img, svg { max-width: 100%; height: auto; }
    * {
      -webkit-print-color-adjust: exact !important;
      print-color-adjust: exact !important;
    }
$breakCss  </style>
</head>
<body>
$html
</body>
</html>
''';
  }

  static String _buildBreakInsideCss(List<String> selectors) {
    if (selectors.isEmpty) return '';
    final joined = selectors.join(',\n    ');
    return '    $joined {\n      page-break-inside: avoid;\n      break-inside: avoid;\n    }\n';
  }

  /// Injects a `<script>` before `</body>` that walks the DOM on load,
  /// finds elements matching [selectors] that would be split across page
  /// boundaries, and pushes them to the next page with margin-top.
  ///
  /// This runs inside the WebView on Android/iOS (where scripts execute),
  /// providing the same smart page-break avoidance as the web platform.
  static String injectPageBreakScript(
    String html, {
    required double pageHeightPt,
    required List<String> selectors,
    double padding = 12.0,
  }) {
    if (selectors.isEmpty) return html;

    final cssPageH = pageHeightPt * 96.0 / 72.0;
    final selectorList =
        selectors.map((s) => "'${s.replaceAll("'", "\\'")}'").join(', ');

    // Override CSS page-break-inside for the target selectors in print mode
    // so only the JS script controls page breaks (with padding).
    // Also reset @page margin to 0 so the JS page-height calculation
    // matches the actual content area per page.
    final selectorCss = selectors.join(',\n  ');
    final overrideStyle = '''
<style>
@media print {
  @page { margin: 0 !important; }
  $selectorCss {
    page-break-inside: auto !important;
    break-inside: auto !important;
  }
}
</style>
''';

    final script = '''
<script>
(function() {
  var cssPageH = $cssPageH;
  var selectors = [$selectorList];
  var padding = $padding;

  function avoidPageBreaks() {
    var selector = selectors.join(', ');
    for (var pass = 0; pass < 10; pass++) {
      var changed = false;
      var elements = document.querySelectorAll(selector);
      for (var i = 0; i < elements.length; i++) {
        var el = elements[i];
        var rect = el.getBoundingClientRect();
        var top = rect.top + window.scrollY;
        var bottom = top + rect.height;
        var startPage = Math.floor(top / cssPageH);
        var endPage = Math.floor((bottom - 1) / cssPageH);
        if (startPage !== endPage && rect.height < cssPageH * 0.85) {
          var pushDown = (startPage + 1) * cssPageH - top + padding;
          el.style.marginTop = (parseFloat(el.style.marginTop || 0) + pushDown) + 'px';
          document.body.offsetHeight;
          changed = true;
        }
      }
      if (!changed) break;
    }
  }

  if (document.readyState === 'complete') {
    avoidPageBreaks();
  } else {
    window.addEventListener('load', avoidPageBreaks);
  }
})();
</script>
''';

    final injection = '$overrideStyle$script';
    final bodyClose =
        RegExp('</body>', caseSensitive: false).firstMatch(html);
    if (bodyClose != null) {
      return html.replaceRange(bodyClose.start, bodyClose.start, injection);
    }
    return '$html$injection';
  }

  static String _buildGoogleFontLinks(List<String> googleFonts) {
    if (googleFonts.isEmpty) return '';

    final buffer = StringBuffer();
    buffer.writeln(
        '  <link rel="preconnect" href="https://fonts.googleapis.com">');
    buffer.writeln(
        '  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>');
    for (final font in googleFonts) {
      final encoded = Uri.encodeComponent(font);
      buffer.writeln(
          '  <link href="https://fonts.googleapis.com/css2?family=$encoded&display=swap" rel="stylesheet">');
    }
    return buffer.toString();
  }

  static String _injectMetadata(
    String html, {
    required String dir,
    required String lang,
    required String fontFamily,
    required List<String> googleFonts,
    List<String> avoidBreakInsideSelectors = const [],
    String backgroundColor = 'white',
  }) {
    var content = html.replaceFirstMapped(
      RegExp(r'<html\b([^>]*)>', caseSensitive: false),
      (match) {
        final attrs = (match.group(1) ?? '')
            .replaceAll(RegExp(r'''\sdir=(["']).*?\1'''), '')
            .replaceAll(RegExp(r'''\slang=(["']).*?\1'''), '');
        return '<html$attrs dir="$dir" lang="$lang">';
      },
    );

    if (!RegExp(r'<meta\s+[^>]*charset=', caseSensitive: false)
        .hasMatch(content)) {
      content = _insertIntoHead(content, '<meta charset="UTF-8">\n');
    }

    for (final font in googleFonts) {
      if (!content.contains(font)) {
        final encoded = Uri.encodeComponent(font);
        content = _insertIntoHead(
          content,
          '<link href="https://fonts.googleapis.com/css2?family=$encoded&display=swap" rel="stylesheet">\n',
        );
      }
    }

    final breakCss = _buildBreakInsideCss(avoidBreakInsideSelectors);
    final pdfStyle = '''
<style>
  @page { size: A4; margin: 12mm; }
  html, body {
    font-family: $fontFamily;
    direction: $dir;
    background: $backgroundColor;
  }
  table { page-break-inside: avoid; width: 100%; }
  thead { display: table-header-group; }
  tfoot { display: table-footer-group; }
  tr { page-break-inside: avoid; }
  * {
    -webkit-print-color-adjust: exact !important;
    print-color-adjust: exact !important;
  }
$breakCss</style>
''';
    content = _insertIntoHead(content, pdfStyle);
    return content;
  }

  static String _insertIntoHead(String html, String insertion) {
    final closeHead =
        RegExp('</head>', caseSensitive: false).firstMatch(html);
    if (closeHead != null) {
      return html.replaceRange(closeHead.start, closeHead.start, insertion);
    }

    final openHead =
        RegExp(r'<head\b[^>]*>', caseSensitive: false).firstMatch(html);
    if (openHead != null) {
      return html.replaceRange(openHead.end, openHead.end, insertion);
    }

    final htmlTag =
        RegExp(r'<html\b[^>]*>', caseSensitive: false).firstMatch(html);
    if (htmlTag != null) {
      return html.replaceRange(
        htmlTag.end,
        htmlTag.end,
        '\n<head>\n$insertion</head>',
      );
    }

    return '$insertion$html';
  }
}
