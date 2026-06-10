import 'dart:typed_data';

import '../models/pdf_options.dart';

class HtmlToPdfConverter {
  Future<dynamic> convertHtmlToPdf({
    required String html,
    required String targetDirectory,
    required String targetName,
    PdfOptions? options,
  }) {
    throw UnsupportedError('convertHtmlToPdf is not supported on this platform');
  }

  Future<Uint8List> convertHtmlToPdfBytes({
    required String html,
    PdfOptions? options,
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
    PdfOptions? options,
  }) {
    throw UnsupportedError('Not supported on this platform');
  }

  Future<Uint8List?> convertHtmlToPdfBytes({
    required String html,
    PdfOptions? options,
  }) {
    throw UnsupportedError('Not supported on this platform');
  }
}
