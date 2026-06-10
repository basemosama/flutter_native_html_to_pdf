import 'package:flutter/services.dart';

import 'pdf_page_size.dart';

class HtmlToPdfConverter {
  static const MethodChannel _channel =
      MethodChannel('flutter_native_html_to_pdf');

  /// Not supported on web. Use [convertHtmlToPdfBytes] instead.
  ///
  /// Throws [UnsupportedError] because web has no filesystem.
  Future<Never> convertHtmlToPdf({
    required String html,
    required String targetDirectory,
    required String targetName,
    PdfPageSize? pageSize,
  }) {
    throw UnsupportedError(
      'convertHtmlToPdf is not supported on web. '
      'Use convertHtmlToPdfBytes instead.',
    );
  }

  Future<Uint8List> convertHtmlToPdfBytes({
    required String html,
    PdfPageSize? pageSize,
  }) async {
    final Uint8List? bytes = await _channel.invokeMethod<Uint8List>(
      'convertHtmlToPdfBytes',
      {
        'html': html,
        if (pageSize != null) 'pageWidth': pageSize.width,
        if (pageSize != null) 'pageHeight': pageSize.height,
      },
    );

    if (bytes == null) {
      throw PlatformException(
        code: 'NULL_RESULT',
        message: 'Web side returned null bytes.',
      );
    }

    return bytes;
  }
}

@Deprecated('Use HtmlToPdfConverter instead')
class FlutterNativeHtmlToPdf {
  final _converter = HtmlToPdfConverter();

  Future<Never> convertHtmlToPdf({
    required String html,
    required String targetDirectory,
    required String targetName,
    PdfPageSize? pageSize,
  }) {
    throw UnsupportedError(
      'convertHtmlToPdf is not supported on web. '
      'Use convertHtmlToPdfBytes instead.',
    );
  }

  Future<Uint8List?> convertHtmlToPdfBytes({
    required String html,
    PdfPageSize? pageSize,
  }) async {
    return _converter.convertHtmlToPdfBytes(
      html: html,
      pageSize: pageSize,
    );
  }
}
