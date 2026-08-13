import 'pdf_page_size.dart';

/// Text direction for HTML content.
enum PdfTextDirection {
  ltr,
  rtl,
}

/// Controls the image encoding used by the web renderer.
enum PdfWebImageFormat {
  /// Use PNG for smaller documents and JPEG for larger documents when enabled.
  auto,

  /// Always encode each rendered page as PNG.
  png,

  /// Always encode each rendered page as JPEG.
  jpeg,
}

/// Web-specific tuning for HTML-to-PDF conversion.
class PdfWebOptions {
  /// Preferred page image encoding for the web raster renderer.
  final PdfWebImageFormat imageFormat;

  /// JPEG quality used when [imageFormat] is [PdfWebImageFormat.jpeg] or when
  /// auto mode switches to JPEG for large documents.
  final double jpegQuality;

  /// When true, the web renderer strips shadows and expensive visual effects
  /// for large documents to improve stability and avoid raster artifacts.
  final bool flattenVisualEffectsForLargeDocuments;

  /// Page-count threshold after which the document is considered large.
  final int largeDocumentPageThreshold;

  /// When true, yields back to the browser between page renders to reduce UI
  /// thread blocking for long conversions.
  final bool yieldBetweenPages;

  const PdfWebOptions({
    this.imageFormat = PdfWebImageFormat.auto,
    this.jpegQuality = 0.86,
    this.flattenVisualEffectsForLargeDocuments = true,
    this.largeDocumentPageThreshold = 8,
    this.yieldBetweenPages = true,
  }) : assert(jpegQuality >= 0 && jpegQuality <= 1),
       assert(largeDocumentPageThreshold > 0);
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

  /// CSS background color for `html` and `body`.
  ///
  /// When omitted, defaults to `'white'`. Set to any valid CSS color
  /// value (e.g. `'#f4f7fb'`, `'transparent'`, `'rgb(244,247,251)'`).
  final String? backgroundColor;

  const HtmlWrapOptions({
    this.direction = PdfTextDirection.ltr,
    this.language = 'en',
    this.fontFamily,
    this.googleFonts = const [],
    this.avoidBreakInsideSelectors = const [],
    this.pageBreakPadding = 12.0,
    this.backgroundColor,
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

  /// Web-only raster tuning options.
  final PdfWebOptions webOptions;

  const PdfOptions({
    this.pageSize = PdfPageSize.a4,
    this.wrapOptions,
    this.webOptions = const PdfWebOptions(),
  });
}
