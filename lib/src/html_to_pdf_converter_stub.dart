import 'dart:typed_data';

import 'pdf_page_size.dart';

class HtmlToPdfConverter {
  Future<dynamic> convertHtmlToPdf({
    required String html,
    required String targetDirectory,
    required String targetName,
    PdfPageSize? pageSize,
  }) {
    throw UnsupportedError('convertHtmlToPdf is not supported on this platform');
  }

  Future<Uint8List> convertHtmlToPdfBytes({
    required String html,
    PdfPageSize? pageSize,
  }) {
    throw UnsupportedError(
        'convertHtmlToPdfBytes is not supported on this platform');
  }
}

@Deprecated('Use HtmlToPdfConverter instead')
class FlutterNativeHtmlToPdf {
  Future<dynamic> convertHtmlToPdf({
    required String html,
    required String targetDirectory,
    required String targetName,
    PdfPageSize? pageSize,
  }) {
    throw UnsupportedError('Not supported on this platform');
  }

  Future<Uint8List?> convertHtmlToPdfBytes({
    required String html,
    PdfPageSize? pageSize,
  }) {
    throw UnsupportedError('Not supported on this platform');
  }
}
