import 'pdf_page_size.dart';

/// Text direction for HTML content.
enum PdfTextDirection {
  ltr,
  rtl,
}

/// Options for wrapping raw HTML with a full document structure
/// containing print-friendly CSS, font loading, and direction support.
///
/// Pass this to [PdfOptions.wrapOptions] to have the converter
/// automatically wrap the HTML before conversion.
///
/// Or use [HtmlPdfHelper.wrapHtml] directly for manual control.
class HtmlWrapOptions {
  /// Text direction (`ltr` or `rtl`).
  final PdfTextDirection direction;

  /// Language code (e.g. `'en'`, `'ar'`, `'fr'`).
  final String language;

  /// CSS font-family value (e.g. `"'Cairo', sans-serif"`).
  ///
  /// When omitted, defaults to `system-ui, sans-serif`.
  final String? fontFamily;

  /// Google Font families to load via `fonts.googleapis.com`.
  ///
  /// Each entry is a font spec like `'Cairo:wght@400;700'`.
  /// The corresponding `<link>` tags are injected into `<head>`.
  final List<String> googleFonts;

  /// CSS selectors for elements that should not be split across pages.
  ///
  /// On Android/iOS, injects `break-inside: avoid` CSS for these selectors
  /// (the native print engine respects it). On web, the plugin pre-processes
  /// the DOM to insert spacers before html2canvas captures.
  ///
  /// Example: `['.report-card', '.report-kv-row', 'tr']`
  final List<String> avoidBreakInsideSelectors;

  /// Extra padding (in CSS pixels) added at the top of the next page when
  /// an element is pushed down to avoid a page break.
  ///
  /// Gives visual breathing room so content doesn't start flush against
  /// the page edge. Defaults to `12.0`.
  final double pageBreakPadding;

  const HtmlWrapOptions({
    this.direction = PdfTextDirection.ltr,
    this.language = 'en',
    this.fontFamily,
    this.googleFonts = const [],
    this.avoidBreakInsideSelectors = const [],
    this.pageBreakPadding = 12.0,
  });
}

/// Options for PDF conversion.
class PdfOptions {
  /// Paper size. Defaults to A4.
  final PdfPageSize pageSize;

  /// When non-null, the converter wraps the HTML with print-friendly
  /// CSS, font loading, and direction support before conversion.
  ///
  /// Set to `null` (default) to pass HTML through as-is.
  final HtmlWrapOptions? wrapOptions;

  const PdfOptions({
    this.pageSize = PdfPageSize.a4,
    this.wrapOptions,
  });
}
