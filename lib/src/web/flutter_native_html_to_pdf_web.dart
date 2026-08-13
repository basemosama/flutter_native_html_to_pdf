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
  JSArray<JSString> avoidBreakSelectors,
  JSNumber pageBreakPadding,
  JSString imageFormat,
  JSNumber jpegQuality,
  JSBoolean flattenVisualEffects,
  JSNumber largeDocumentPageThreshold,
  JSBoolean yieldBetweenPages,
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
        final selectors = (args['avoidBreakSelectors'] as List?)?.cast<String>() ?? [];
        final breakPadding = (args['pageBreakPadding'] as num?)?.toDouble() ?? 12.0;
        final imageFormat = (args['webImageFormat'] as String?) ?? 'auto';
        final jpegQuality = (args['webJpegQuality'] as num?)?.toDouble() ?? 0.86;
        final flattenVisualEffects = args['webFlattenVisualEffects'] as bool? ?? true;
        final largeDocumentPageThreshold =
            (args['webLargeDocumentPageThreshold'] as num?)?.toInt() ?? 8;
        final yieldBetweenPages = args['webYieldBetweenPages'] as bool? ?? true;
        return _convertHtmlToPdfBytes(
          html,
          pageWidth,
          pageHeight,
          selectors,
          breakPadding,
          imageFormat,
          jpegQuality,
          flattenVisualEffects,
          largeDocumentPageThreshold,
          yieldBetweenPages,
        );
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
    List<String> avoidBreakSelectors,
    double breakPadding,
    String imageFormat,
    double jpegQuality,
    bool flattenVisualEffects,
    int largeDocumentPageThreshold,
    bool yieldBetweenPages,
  ) async {
    final width = pageWidth ?? 595.2;
    final height = pageHeight ?? 841.8;

    await _ensureHelperLoaded();

    final jsSelectors = avoidBreakSelectors.map((s) => s.toJS).toList().toJS;
    final promise = _callHelper(
      html.toJS,
      width.toJS,
      height.toJS,
      jsSelectors,
      breakPadding.toJS,
      imageFormat.toJS,
      jpegQuality.toJS,
      flattenVisualEffects.toJS,
      largeDocumentPageThreshold.toJS,
      yieldBetweenPages.toJS,
    );
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

    final script = web.document.createElement('script') as web.HTMLScriptElement;
    script.textContent = r'''window.__flutterHtmlToPdf = async function(
  htmlString,
  pageWidth,
  pageHeight,
  avoidBreakSelectors,
  pageBreakPadding,
  imageFormat,
  jpegQuality,
  flattenVisualEffects,
  largeDocumentPageThreshold,
  yieldBetweenPages
) {
  var cssWidth = pageWidth * 96.0 / 72.0;
  var cssPageHeight = pageHeight * 96.0 / 72.0;

  var parser = new DOMParser();
  var doc = parser.parseFromString(htmlString, 'text/html');

  var addedLinks = [];
  var links = doc.querySelectorAll('head link');
  for (var i = 0; i < links.length; i++) {
    var clone = links[i].cloneNode(true);
    document.head.appendChild(clone);
    addedLinks.push(clone);
  }

  var container = document.createElement('div');
  container.style.position = 'absolute';
  container.style.left = '-100000px';
  container.style.top = '0';
  container.style.width = cssWidth + 'px';
  container.style.overflowX = 'hidden';
  container.style.overflowY = 'visible';
  container.style.boxSizing = 'border-box';

  var bodyStyle = doc.body.getAttribute('style');
  if (bodyStyle) {
    container.setAttribute('style', bodyStyle);
    container.style.position = 'absolute';
    container.style.left = '-100000px';
    container.style.top = '0';
    container.style.width = cssWidth + 'px';
    container.style.overflowX = 'hidden';
    container.style.overflowY = 'visible';
    container.style.boxSizing = 'border-box';
  }

  var styles = doc.querySelectorAll('style');
  for (var j = 0; j < styles.length; j++) {
    container.appendChild(styles[j].cloneNode(true));
  }

  while (doc.body.firstChild) {
    container.appendChild(doc.body.firstChild);
  }

  var fixStyle = document.createElement('style');
  fixStyle.textContent = [
    '* { letter-spacing: normal !important; }',
    '* { animation: none !important; transition: none !important; }',
    'html, body { margin: 0 !important; padding: 0 !important; }'
  ].join(' ');
  container.insertBefore(fixStyle, container.firstChild);

  document.body.appendChild(container);

  var flattenStyle = null;

  function cleanup() {
    if (flattenStyle && flattenStyle.parentNode) {
      flattenStyle.parentNode.removeChild(flattenStyle);
    }
    if (container.parentNode) {
      container.parentNode.removeChild(container);
    }
    for (var i = 0; i < addedLinks.length; i++) {
      if (addedLinks[i].parentNode) {
        addedLinks[i].parentNode.removeChild(addedLinks[i]);
      }
    }
  }

  function nextFrame() {
    return new Promise(function(resolve) {
      requestAnimationFrame(function() {
        requestAnimationFrame(resolve);
      });
    });
  }

  function yieldToBrowser(timeout) {
    return new Promise(function(resolve) {
      if (!yieldBetweenPages) {
        resolve();
        return;
      }
      if (window.requestIdleCallback) {
        window.requestIdleCallback(function() { resolve(); }, { timeout: timeout || 16 });
        return;
      }
      setTimeout(resolve, timeout || 16);
    });
  }

  function waitForFonts() {
    if (!document.fonts || !document.fonts.ready) {
      return Promise.resolve();
    }
    return document.fonts.ready.catch(function() {});
  }

  function waitForImages(root) {
    var images = Array.prototype.slice.call(root.querySelectorAll('img'));
    if (images.length === 0) {
      return Promise.resolve();
    }

    return Promise.all(images.map(function(img) {
      if (img.complete) {
        return Promise.resolve();
      }
      return new Promise(function(resolve) {
        var done = function() {
          img.removeEventListener('load', done);
          img.removeEventListener('error', done);
          resolve();
        };
        img.addEventListener('load', done, { once: true });
        img.addEventListener('error', done, { once: true });
      });
    }));
  }

  function rasterizeSvgImages() {
    var svgImgs = container.querySelectorAll('img[src^="data:image/svg"]');
    var promises = [];
    svgImgs.forEach(function(imgEl) {
      promises.push(new Promise(function(resolve) {
        var w = imgEl.clientWidth || imgEl.offsetWidth;
        var h = imgEl.clientHeight || imgEl.offsetHeight;
        if (!w || !h) {
          resolve();
          return;
        }

        var tmp = new Image();
        tmp.onload = function() {
          var c = document.createElement('canvas');
          var s = 2;
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

  function avoidPageBreaks() {
    if (!avoidBreakSelectors || avoidBreakSelectors.length === 0) {
      return;
    }

    var selector = avoidBreakSelectors.join(', ');

    for (var pass = 0; pass < 10; pass++) {
      var changed = false;
      var elements = container.querySelectorAll(selector);
      var containerTop = container.getBoundingClientRect().top;

      for (var i = 0; i < elements.length; i++) {
        var el = elements[i];
        var rect = el.getBoundingClientRect();
        var top = rect.top - containerTop;
        var bottom = top + rect.height;

        var startPage = Math.floor(top / cssPageHeight);
        var endPage = Math.floor((bottom - 1) / cssPageHeight);

        if (startPage !== endPage && rect.height < cssPageHeight * 0.85) {
          var pushDown = (startPage + 1) * cssPageHeight - top + (pageBreakPadding || 0);
          el.style.marginTop = (parseFloat(el.style.marginTop || 0) + pushDown) + 'px';
          container.offsetHeight;
          changed = true;
        }
      }

      if (!changed) {
        break;
      }
    }
  }

  function resolveBackgroundColor() {
    var colors = [
      window.getComputedStyle(container).backgroundColor,
      window.getComputedStyle(document.body).backgroundColor,
      window.getComputedStyle(document.documentElement).backgroundColor,
    ];

    for (var i = 0; i < colors.length; i++) {
      var color = colors[i];
      if (color && color !== 'rgba(0, 0, 0, 0)' && color !== 'transparent') {
        return color;
      }
    }

    return '#ffffff';
  }

  function computeRenderScale(totalHeight) {
    var estimatedPages = Math.max(1, Math.ceil(totalHeight / cssPageHeight));
    if (estimatedPages > 24) {
      return 1;
    }
    if (estimatedPages > 12) {
      return 1.15;
    }
    if (estimatedPages > 6) {
      return 1.35;
    }
    return 1.75;
  }

  function applyLargeDocumentOptimizations() {
    flattenStyle = document.createElement('style');
    flattenStyle.textContent = [
      '* { box-shadow: none !important; text-shadow: none !important; filter: none !important; backdrop-filter: none !important; }',
      '*::before, *::after { box-shadow: none !important; text-shadow: none !important; filter: none !important; backdrop-filter: none !important; }'
    ].join(' ');
    container.insertBefore(flattenStyle, container.firstChild);
  }

  function resolveImageSettings(isLargeDocument) {
    var normalized = (imageFormat || 'auto').toLowerCase();
    if (normalized === 'jpeg') {
      return { format: 'JPEG', mimeType: 'image/jpeg', quality: jpegQuality || 0.86 };
    }
    if (normalized === 'png') {
      return { format: 'PNG', mimeType: 'image/png', quality: 1 };
    }
    if (isLargeDocument) {
      return { format: 'JPEG', mimeType: 'image/jpeg', quality: jpegQuality || 0.86 };
    }
    return { format: 'PNG', mimeType: 'image/png', quality: 1 };
  }

  function renderPage(pageTop, pageHeightCss, renderScale, backgroundColor) {
    var viewport = document.createElement('div');
    viewport.style.position = 'absolute';
    viewport.style.left = '-100000px';
    viewport.style.top = '0';
    viewport.style.width = cssWidth + 'px';
    viewport.style.height = Math.max(1, Math.ceil(pageHeightCss)) + 'px';
    viewport.style.overflow = 'hidden';
    viewport.style.background = backgroundColor;
    viewport.style.boxSizing = 'border-box';

    var cloned = container.cloneNode(true);
    cloned.style.position = 'relative';
    cloned.style.left = '0';
    cloned.style.width = cssWidth + 'px';
    cloned.style.overflow = 'hidden';
    cloned.style.top = (-pageTop) + 'px';
    cloned.style.boxSizing = 'border-box';

    viewport.appendChild(cloned);
    document.body.appendChild(viewport);

    return html2canvas(viewport, {
      scale: renderScale,
      useCORS: true,
      backgroundColor: backgroundColor,
      scrollX: 0,
      scrollY: 0,
      windowWidth: Math.ceil(cssWidth),
      windowHeight: Math.max(1, Math.ceil(pageHeightCss)),
      imageTimeout: 0,
      logging: false,
      removeContainer: true,
    }).then(function(canvas) {
      if (viewport.parentNode) {
        viewport.parentNode.removeChild(viewport);
      }
      return canvas;
    }).catch(function(error) {
      if (viewport.parentNode) {
        viewport.parentNode.removeChild(viewport);
      }
      throw error;
    });
  }

  try {
    await waitForFonts();
    await waitForImages(container);
    await rasterizeSvgImages();
    await nextFrame();
    avoidPageBreaks();
    await nextFrame();

    var totalHeight = Math.max(
      container.scrollHeight,
      container.offsetHeight,
      Math.ceil(container.getBoundingClientRect().height)
    );
    var backgroundColor = resolveBackgroundColor();
    var renderScale = computeRenderScale(totalHeight);
    var totalPages = Math.max(1, Math.ceil(totalHeight / cssPageHeight));
    var isLargeDocument = totalPages >= (largeDocumentPageThreshold || 8);
    var imageSettings = resolveImageSettings(isLargeDocument);

    if (isLargeDocument && flattenVisualEffects) {
      applyLargeDocumentOptimizations();
      await nextFrame();
    }

    var pdf = new jspdf.jsPDF({
      unit: 'pt',
      format: [pageWidth, pageHeight],
      orientation: pageWidth > pageHeight ? 'landscape' : 'portrait'
    });

    for (var pageIndex = 0; pageIndex < totalPages; pageIndex++) {
      if (pageIndex > 0) {
        pdf.addPage();
      }

      await yieldToBrowser(pageIndex === 0 ? 0 : 16);

      var pageTop = pageIndex * cssPageHeight;
      var remainingHeight = totalHeight - pageTop;
      var pageHeightCss = Math.max(1, Math.min(cssPageHeight, remainingHeight));
      var pageCanvas = await renderPage(
        pageTop,
        pageHeightCss,
        renderScale,
        backgroundColor,
      );
      var imageData = pageCanvas.toDataURL(imageSettings.mimeType, imageSettings.quality);
      var imageHeightPt = pageCanvas.height * pageWidth / pageCanvas.width;

      pdf.addImage(
        imageData,
        imageSettings.format,
        0,
        0,
        pageWidth,
        imageHeightPt,
        undefined,
        'FAST',
      );

      pageCanvas.width = 1;
      pageCanvas.height = 1;
      await nextFrame();
    }

    cleanup();
    return pdf.output('arraybuffer');
  } catch (error) {
    cleanup();
    throw error;
  }
};''';
    web.document.head!.append(script);
    _helperLoaded = true;
  }

  Future<void> _loadScript(String url) async {
    final completer = Completer<void>();
    final script = web.document.createElement('script') as web.HTMLScriptElement;
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
