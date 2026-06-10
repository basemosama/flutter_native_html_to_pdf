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

    if (RegExp(r'<html\b[^>]*>', caseSensitive: false).hasMatch(html)) {
      return _injectMetadata(
        html,
        dir: dir,
        lang: lang,
        fontFamily: fontFamily,
        googleFonts: googleFonts,
      );
    }

    final fontLinks = _buildGoogleFontLinks(googleFonts);

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
      background: white;
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
  </style>
</head>
<body>
$html
</body>
</html>
''';
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

    final pdfStyle = '''
<style>
  @page { size: A4; margin: 12mm; }
  html, body {
    font-family: $fontFamily;
    direction: $dir;
    background: white;
  }
  table { page-break-inside: avoid; width: 100%; }
  thead { display: table-header-group; }
  tfoot { display: table-footer-group; }
  tr { page-break-inside: avoid; }
</style>
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
