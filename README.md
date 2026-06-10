# Flutter Native HTML to PDF

A Flutter plugin that converts HTML to high-quality PDF files using native platform rendering. Uses Android WebView, iOS WKWebView, and html2canvas + jsPDF on web.

## Features

- **Cross-platform**: Android, iOS, and Web
- **Native rendering**: Uses platform WebView engines for pixel-perfect output on mobile
- **Two conversion modes**: Save to file (`convertHtmlToPdf`) or get bytes (`convertHtmlToPdfBytes`)
- **Customizable page sizes**: A4, Letter, Legal, A3, A5, B5, Executive, Tabloid, or custom dimensions
- **HTML wrapping utilities**: Optional helpers for fonts, RTL/LTR direction, page break control, and background color
- **Smart page breaks**: Prevent elements from being split across pages on all platforms

## Installation

```yaml
dependencies:
  flutter_native_html_to_pdf: ^3.1.0
```

## Platform Support

| Platform | Rendering Engine | `convertHtmlToPdf` | `convertHtmlToPdfBytes` |
|----------|-----------------|-------------------|----------------------|
| Android  | Android WebView | Yes | Yes |
| iOS      | WKWebView       | Yes | Yes |
| Web      | html2canvas + jsPDF | No (throws `UnsupportedError`) | Yes |

## Quick Start

### Convert HTML to PDF Bytes (all platforms)

```dart
import 'package:flutter_native_html_to_pdf/flutter_native_html_to_pdf.dart';

final converter = HtmlToPdfConverter();

final bytes = await converter.convertHtmlToPdfBytes(
  html: '<h1>Hello World</h1><p>This is a PDF.</p>',
);

// Use bytes to save, upload, share, etc.
```

### Convert HTML to PDF File (Android & iOS only)

```dart
import 'package:path_provider/path_provider.dart';

final dir = await getApplicationDocumentsDirectory();
final file = await converter.convertHtmlToPdf(
  html: '<h1>Hello World</h1>',
  targetDirectory: dir.path,
  targetName: 'my_document',
);

print('PDF saved at: ${file.path}');
```

## PdfOptions

Pass `PdfOptions` to control page size and enable HTML wrapping:

```dart
final bytes = await converter.convertHtmlToPdfBytes(
  html: htmlContent,
  options: PdfOptions(
    pageSize: PdfPageSize.a4,
  ),
);
```

### Custom Page Sizes

```dart
// Predefined sizes
PdfPageSize.a4        // 210mm x 297mm (default)
PdfPageSize.letter    // 8.5" x 11"
PdfPageSize.legal     // 8.5" x 14"
PdfPageSize.a3        // 297mm x 420mm
PdfPageSize.a5        // 148mm x 210mm
PdfPageSize.b5        // 176mm x 250mm
PdfPageSize.executive // 7.25" x 10.5"
PdfPageSize.tabloid   // 11" x 17"

// Custom size in points (72 points = 1 inch)
PdfPageSize.custom(width: 500, height: 700, name: 'My Size');

// From millimeters
PdfPageSize.fromMillimeters(widthMm: 210, heightMm: 297);

// From inches
PdfPageSize.fromInches(widthInches: 8.5, heightInches: 11);

// Orientation
PdfPageSize.a4.landscape;
PdfPageSize.a4.portrait;
```

## HtmlWrapOptions

Optional HTML wrapping that adds print-friendly CSS, font loading, and direction support. Set `PdfOptions.wrapOptions` to enable:

```dart
final bytes = await converter.convertHtmlToPdfBytes(
  html: '<div class="card">Report content...</div>',
  options: PdfOptions(
    pageSize: PdfPageSize.a4,
    wrapOptions: HtmlWrapOptions(
      direction: PdfTextDirection.rtl,
      language: 'ar',
      fontFamily: "'Cairo', sans-serif",
      googleFonts: ['Cairo:wght@400;700'],
      backgroundColor: '#f4f7fb',
      avoidBreakInsideSelectors: ['.card', 'tr'],
      pageBreakPadding: 16.0,
    ),
  ),
);
```

### All Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `direction` | `PdfTextDirection` | `ltr` | Text direction (`ltr` or `rtl`) |
| `language` | `String` | `'en'` | Language code (`'en'`, `'ar'`, `'fr'`, etc.) |
| `fontFamily` | `String?` | `system-ui, sans-serif` | CSS font-family value |
| `googleFonts` | `List<String>` | `[]` | Google Font specs to load (e.g. `['Cairo:wght@400;700']`) |
| `backgroundColor` | `String?` | `'white'` | CSS background color for html/body |
| `avoidBreakInsideSelectors` | `List<String>` | `[]` | CSS selectors for elements that should not split across pages |
| `pageBreakPadding` | `double` | `12.0` | Extra top padding (px) when an element is pushed to the next page |

### How Wrapping Works

When `wrapOptions` is set:

1. If the HTML is a fragment (no `<html>` tag), it's wrapped in a full HTML document with `<head>`, `<body>`, and print-friendly CSS
2. If the HTML already has an `<html>` tag, the metadata (direction, fonts, styles) is injected into the existing structure
3. Google Fonts `<link>` tags are added to `<head>`
4. CSS `break-inside: avoid` is injected for `avoidBreakInsideSelectors`
5. A page-break avoidance script is injected that runs in the WebView (Android/iOS) or before html2canvas (web), pushing elements that would be split to the next page

### Manual Wrapping

You can also call `HtmlPdfHelper.wrapHtml` directly without using `PdfOptions.wrapOptions`:

```dart
final wrappedHtml = HtmlPdfHelper.wrapHtml(
  rawContent,
  options: HtmlWrapOptions(
    direction: PdfTextDirection.rtl,
    language: 'ar',
    googleFonts: ['Cairo:wght@400;700'],
  ),
);

final bytes = await converter.convertHtmlToPdfBytes(html: wrappedHtml);
```

## Page Break Control

### Automatic (via selectors)

Specify CSS selectors for elements that should not be split across pages:

```dart
PdfOptions(
  wrapOptions: HtmlWrapOptions(
    avoidBreakInsideSelectors: [
      '.report-card',    // don't split cards
      '.data-row',       // don't split rows
      'tr',              // don't split table rows
    ],
    pageBreakPadding: 12.0, // breathing room at top of new page
  ),
)
```

**How it works per platform:**
- **Android/iOS**: Injects CSS `break-inside: avoid` (native print engines respect it) and a JavaScript that adjusts element positions at page boundaries
- **Web**: Pre-processes the DOM before html2canvas captures, inserting margin to push boundary-crossing elements to the next page

### Manual (via CSS classes in your HTML)

Add standard CSS page-break classes in your HTML:

```html
<div class="section" style="page-break-inside: avoid;">
  <!-- This section won't be split -->
</div>

<div style="page-break-before: always;">
  <!-- This starts on a new page -->
</div>
```

On Android/iOS, the native print engines respect these CSS rules directly. On web, use `avoidBreakInsideSelectors` for the same effect.

## Web Platform Notes

On web, `convertHtmlToPdfBytes` uses [html2canvas](https://html2canvas.hertzen.com/) and [jsPDF](https://github.com/parallax/jsPDF) (loaded from CDN automatically). Key differences from native:

- `convertHtmlToPdf` (file-based) is **not supported** — throws `UnsupportedError`. Use `convertHtmlToPdfBytes` instead
- Output is rasterized (image-based PDF), not vector. Text is not selectable in the PDF
- Some complex CSS (box-shadow, certain gradients) may render slightly differently than the browser
- SVG data-URI images are automatically pre-rasterized to PNG for compatibility
- `letter-spacing` CSS is reset to prevent Arabic ligature issues with html2canvas

### Downloading the PDF on Web

```dart
import 'package:flutter/foundation.dart';

final bytes = await converter.convertHtmlToPdfBytes(html: html);

if (kIsWeb) {
  // Trigger browser download — use the download_helper from the example app
  downloadPdfBytes(bytes, 'report.pdf');
} else {
  // Save to file on mobile
  final file = File('/path/to/report.pdf');
  await file.writeAsBytes(bytes);
}
```

## Full Example

```dart
import 'package:flutter_native_html_to_pdf/flutter_native_html_to_pdf.dart';

final converter = HtmlToPdfConverter();

const html = '''
<!DOCTYPE html>
<html>
<head>
  <style>
    body { font-family: Arial, sans-serif; margin: 20px; }
    .card {
      background: white;
      border-radius: 12px;
      padding: 24px;
      margin-bottom: 16px;
      box-shadow: 0 2px 8px rgba(0,0,0,0.1);
    }
    h1 { color: #1d4ed8; }
    table { width: 100%; border-collapse: collapse; }
    th, td { padding: 8px 12px; border-bottom: 1px solid #e5e7eb; }
    th { background: #eff6ff; text-align: left; }
  </style>
</head>
<body>
  <h1>Monthly Report</h1>
  <div class="card">
    <h2>Summary</h2>
    <table>
      <thead><tr><th>Metric</th><th>Value</th></tr></thead>
      <tbody>
        <tr><td>Revenue</td><td>\$12,500</td></tr>
        <tr><td>Users</td><td>1,234</td></tr>
      </tbody>
    </table>
  </div>
</body>
</html>
''';

final bytes = await converter.convertHtmlToPdfBytes(
  html: html,
  options: PdfOptions(
    pageSize: PdfPageSize.a4,
    wrapOptions: HtmlWrapOptions(
      avoidBreakInsideSelectors: ['.card', 'tr'],
    ),
  ),
);
```

## Android Configuration

Add internet permission for external images/fonts in `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
```

## iOS Configuration

For external resources, add to `ios/Runner/Info.plist`:

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

## Migration from v2.x

The `pageSize` parameter has been replaced by `PdfOptions`:

```dart
// v2.x
await converter.convertHtmlToPdfBytes(
  html: html,
  pageSize: PdfPageSize.letter,
);

// v3.x
await converter.convertHtmlToPdfBytes(
  html: html,
  options: PdfOptions(pageSize: PdfPageSize.letter),
);
```

The deprecated `FlutterNativeHtmlToPdf` class still works but use `HtmlToPdfConverter` for new code.
