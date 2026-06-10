/// A Flutter plugin for converting HTML to PDF using native WebView rendering.
///
/// On **Android**, the HTML is loaded into an offscreen [WebView] and exported
/// to PDF via the Android print framework (`PrintDocumentAdapter`).
/// On **iOS**, the HTML is loaded into a [WKWebView] and the PDF data is
/// produced with `WKWebView.createPDF` (iOS 14+) or `UIPrintPageRenderer`
/// (iOS 12–13).
/// On **Web**, the HTML is rendered in a hidden element and converted to PDF
/// using html2pdf.js.
///
/// ## Usage
///
/// ```dart
/// import 'package:flutter_native_html_to_pdf/flutter_native_html_to_pdf.dart';
///
/// // Create an instance of the converter
/// final converter = HtmlToPdfConverter();
///
/// // Convert HTML to a PDF file (not supported on web)
/// final file = await converter.convertHtmlToPdf(
///   html: '<h1>Hello World</h1>',
///   targetDirectory: '/path/to/directory',
///   targetName: 'my_document',
/// );
///
/// // Or convert HTML to PDF bytes (works on all platforms)
/// final bytes = await converter.convertHtmlToPdfBytes(
///   html: '<h1>Hello World</h1>',
/// );
/// ```
library;

export 'src/html_to_pdf_converter_stub.dart'
    if (dart.library.io) 'src/html_to_pdf_converter_io.dart'
    if (dart.library.js_interop) 'src/html_to_pdf_converter_web.dart';
export 'src/pdf_page_size.dart';
