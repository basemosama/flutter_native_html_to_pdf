import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:web/web.dart' as web;

@JS('window.__flutterHtmlToPdf')
external JSPromise<JSAny?> _callHelper(
  JSString html,
  JSNumber width,
  JSNumber height,
);

class FlutterNativeHtmlToPdfWeb {
  static void registerWith(Registrar registrar) {
    final channel = MethodChannel(
      'flutter_native_html_to_pdf',
      const StandardMethodCodec(),
      registrar,
    );
    final instance = FlutterNativeHtmlToPdfWeb();
    channel.setMethodCallHandler(instance.handleMethodCall);
  }

  Future<dynamic> handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'convertHtmlToPdfBytes':
        final args = call.arguments as Map;
        final html = args['html'] as String;
        final pageWidth = args['pageWidth'] as double?;
        final pageHeight = args['pageHeight'] as double?;
        return _convertHtmlToPdfBytes(html, pageWidth, pageHeight);
      case 'convertHtmlToPdf':
        throw PlatformException(
          code: 'UNSUPPORTED',
          message:
              'convertHtmlToPdf is not supported on web. Use convertHtmlToPdfBytes instead.',
        );
      default:
        throw PlatformException(
          code: 'UNIMPLEMENTED',
          message: '${call.method} is not implemented on web.',
        );
    }
  }

  Future<Uint8List> _convertHtmlToPdfBytes(
    String html,
    double? pageWidth,
    double? pageHeight,
  ) async {
    final width = pageWidth ?? 595.2;
    final height = pageHeight ?? 841.8;

    await _ensureHelperLoaded();

    final promise = _callHelper(html.toJS, width.toJS, height.toJS);
    final result = await promise.toDart;
    if (result == null) {
      throw PlatformException(
        code: 'PDF_ERROR',
        message: 'html2pdf.js returned null.',
      );
    }

    final arrayBuffer = result as JSArrayBuffer;
    return arrayBuffer.toDart.asUint8List();
  }

  static bool _html2PdfLoaded = false;
  static bool _helperLoaded = false;

  Future<void> _ensureHelperLoaded() async {
    if (_helperLoaded) return;
    await _ensureHtml2PdfLoaded();

    final script =
        web.document.createElement('script') as web.HTMLScriptElement;
    script.textContent = r'''
window.__flutterHtmlToPdf = function(htmlString, pageWidth, pageHeight) {
  var cssWidth = pageWidth * 96.0 / 72.0;

  var parser = new DOMParser();
  var doc = parser.parseFromString(htmlString, 'text/html');

  // Move <link rel="stylesheet"> and <link rel="preconnect"> to the real
  // document <head> so the browser loads fonts/stylesheets properly.
  // (<link> tags don't work inside <div>.)
  var addedLinks = [];
  var links = doc.querySelectorAll('head link');
  for (var i = 0; i < links.length; i++) {
    var clone = links[i].cloneNode(true);
    document.head.appendChild(clone);
    addedLinks.push(clone);
  }

  // Build the rendering container.
  var container = document.createElement('div');
  container.style.width = cssWidth + 'px';
  container.style.overflowX = 'hidden';

  // Copy body inline styles (font-family, direction, margin, etc.)
  var bodyStyle = doc.body.getAttribute('style');
  if (bodyStyle) container.setAttribute('style', 'width:' + cssWidth + 'px;overflow-x:hidden;' + bodyStyle);

  // Copy ALL <style> tags (from <head> and <body>)
  var styles = doc.querySelectorAll('style');
  for (var i = 0; i < styles.length; i++) {
    container.appendChild(styles[i].cloneNode(true));
  }

  // Move body children (the actual content) into the container
  while (doc.body.firstChild) {
    container.appendChild(doc.body.firstChild);
  }

  // html2canvas renders each character individually when letter-spacing
  // is set, which breaks Arabic ligature connections. Reset it.
  var fixStyle = document.createElement('style');
  fixStyle.textContent = '* { letter-spacing: normal !important; }';
  container.insertBefore(fixStyle, container.firstChild);

  document.body.appendChild(container);

  function cleanup() {
    document.body.removeChild(container);
    for (var i = 0; i < addedLinks.length; i++) {
      if (addedLinks[i].parentNode) addedLinks[i].parentNode.removeChild(addedLinks[i]);
    }
  }

  // Pre-convert SVG data-URI <img> tags to PNG so html2canvas can render them.
  function rasterizeSvgImages() {
    var svgImgs = container.querySelectorAll('img[src^="data:image/svg"]');
    var promises = [];
    svgImgs.forEach(function(imgEl) {
      promises.push(new Promise(function(resolve) {
        // Use the DOM-rendered dimensions, not naturalWidth/Height
        // (SVGs without explicit width/height return wrong natural sizes).
        var w = imgEl.clientWidth || imgEl.offsetWidth;
        var h = imgEl.clientHeight || imgEl.offsetHeight;
        if (!w || !h) { resolve(); return; }

        var tmp = new Image();
        tmp.onload = function() {
          var c = document.createElement('canvas');
          var s = 4; // high-res rasterization
          c.width = w * s;
          c.height = h * s;
          var ctx = c.getContext('2d');
          ctx.scale(s, s);
          ctx.drawImage(tmp, 0, 0, w, h);
          imgEl.src = c.toDataURL('image/png');
          resolve();
        };
        tmp.onerror = function() { resolve(); };
        tmp.src = imgEl.src;
      }));
    });
    return Promise.all(promises);
  }

  // Wait for web fonts, then rasterize SVGs, then capture.
  return document.fonts.ready.then(function() {
    return rasterizeSvgImages();
  }).then(function() {
    return new Promise(function(resolve) { setTimeout(resolve, 200); });
  }).then(function() {
    return html2canvas(container, {
      scale: 2,
      useCORS: true,
      scrollY: 0
    });
  }).then(function(canvas) {
    var pdf = new jspdf.jsPDF({
      unit: 'pt',
      format: [pageWidth, pageHeight],
      orientation: pageWidth > pageHeight ? 'landscape' : 'portrait'
    });

    // Slice the canvas into per-page chunks. Each page gets only its
    // own image data instead of the entire full-height canvas, which
    // cuts file size from ~190MB to a few MB.
    var canvasPageHeight = Math.floor(canvas.width * pageHeight / pageWidth);
    var totalPages = Math.ceil(canvas.height / canvasPageHeight);

    for (var p = 0; p < totalPages; p++) {
      if (p > 0) pdf.addPage();

      var sliceH = Math.min(canvasPageHeight, canvas.height - p * canvasPageHeight);
      var sliceCanvas = document.createElement('canvas');
      sliceCanvas.width = canvas.width;
      sliceCanvas.height = sliceH;
      var sliceCtx = sliceCanvas.getContext('2d');
      sliceCtx.drawImage(
        canvas,
        0, p * canvasPageHeight, canvas.width, sliceH,
        0, 0, canvas.width, sliceH
      );

      var sliceData = sliceCanvas.toDataURL('image/jpeg', 0.98);
      var sliceImgH = sliceH * pageWidth / canvas.width;
      pdf.addImage(sliceData, 'JPEG', 0, 0, pageWidth, sliceImgH);
    }

    cleanup();
    return pdf.output('arraybuffer');
  }).catch(function(err) {
    cleanup();
    throw err;
  });
};
''';
    web.document.head!.append(script);
    _helperLoaded = true;
  }

  Future<void> _loadScript(String url) async {
    final completer = Completer<void>();
    final script =
        web.document.createElement('script') as web.HTMLScriptElement;
    script.src = url;
    script.type = 'text/javascript';

    script.onload = ((web.Event _) {
      completer.complete();
    }).toJS;

    script.onerror = ((web.Event _) {
      completer.completeError(
        PlatformException(
          code: 'SCRIPT_LOAD_ERROR',
          message: 'Failed to load $url',
        ),
      );
    }).toJS;

    web.document.head!.append(script);
    return completer.future;
  }

  Future<void> _ensureHtml2PdfLoaded() async {
    if (_html2PdfLoaded) return;

    final needsHtml2Canvas = globalContext['html2canvas'] == null;
    final needsJsPdf = globalContext['jspdf'] == null;

    final futures = <Future>[];
    if (needsHtml2Canvas) {
      futures.add(
        _loadScript(
          'https://cdnjs.cloudflare.com/ajax/libs/html2canvas/1.4.1/html2canvas.min.js',
        ),
      );
    }
    if (needsJsPdf) {
      futures.add(
        _loadScript(
          'https://cdnjs.cloudflare.com/ajax/libs/jspdf/2.5.1/jspdf.umd.min.js',
        ),
      );
    }

    await Future.wait(futures);
    _html2PdfLoaded = true;
  }
}
