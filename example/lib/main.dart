import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_html_to_pdf/flutter_native_html_to_pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'download_helper.dart'
    if (dart.library.js_interop) 'download_helper_web.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String? generatedPdfFilePath;
  Uint8List? generatedPdfBytes;
  PdfPageSize selectedPageSize = PdfPageSize.a4;
  bool isCustomSize = false;
  bool isLoading = false;
  String? htmlContent;
  final TextEditingController _widthController =
      TextEditingController(text: '210');
  final TextEditingController _heightController =
      TextEditingController(text: '297');
  String _customUnit = 'mm';

  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  final _converter = HtmlToPdfConverter();

  @override
  void initState() {
    super.initState();
    _loadHtml();
  }

  Future<void> _loadHtml() async {
    final html = await rootBundle.loadString('assets/arabic-report.html');
    setState(() => htmlContent = html);
    print('html:$html');
  }

  @override
  void dispose() {
    _widthController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  PdfPageSize _getPageSizeByName(String name) {
    switch (name) {
      case 'A4':
        return PdfPageSize.a4;
      case 'Letter':
        return PdfPageSize.letter;
      case 'Legal':
        return PdfPageSize.legal;
      case 'A3':
        return PdfPageSize.a3;
      case 'A5':
        return PdfPageSize.a5;
      case 'Tabloid':
        return PdfPageSize.tabloid;
      default:
        return PdfPageSize.a4;
    }
  }

  PdfPageSize _getEffectivePageSize() {
    if (!isCustomSize) return selectedPageSize;

    final width = double.tryParse(_widthController.text) ?? 210;
    final height = double.tryParse(_heightController.text) ?? 297;

    switch (_customUnit) {
      case 'mm':
        return PdfPageSize.fromMillimeters(
          widthMm: width,
          heightMm: height,
          name: 'Custom (${width}mm x ${height}mm)',
        );
      case 'in':
        return PdfPageSize.fromInches(
          widthInches: width,
          heightInches: height,
          name: 'Custom ($width" x $height")',
        );
      case 'pt':
        return PdfPageSize.custom(
          width: width,
          height: height,
          name: 'Custom (${width}pt x ${height}pt)',
        );
      default:
        return PdfPageSize.fromMillimeters(widthMm: width, heightMm: height);
    }
  }

  void _showSnackBar(String message, {Color? color}) {
    if (!mounted) return;
    _messengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _generatePdfBytes() async {
    if (htmlContent == null) return;
    setState(() => isLoading = true);

    try {
      final pageSize = _getEffectivePageSize();
      _showSnackBar(
        'Converting to PDF bytes (${pageSize.name})...',
        color: Colors.blue,
      );

      final bytes = await _converter.convertHtmlToPdfBytes(
        html: htmlContent!,
        options: PdfOptions(
          pageSize: pageSize,
          wrapOptions: HtmlWrapOptions(
            direction: PdfTextDirection.rtl,
            language: 'ar',
            avoidBreakInsideSelectors: [
              '.report-card',
              '.report-kv-row',
              '.report-grid-3',
            ],
          ),
        ),
      );
      print(
        'PDF generated! ${bytes.length} bytes',
      );

      setState(() => generatedPdfBytes = bytes);
      _showSnackBar(
        'PDF generated! ${bytes.length} bytes',
        color: Colors.green,
      );
    } catch (e, s) {
      setState(() => generatedPdfBytes = null);
      _showSnackBar('Failed: $e\n$s', color: Colors.red);
      print('ERROR: $e\n$s');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _downloadPdf() async {
    if (generatedPdfBytes == null) await _generatePdfBytes();
    if (generatedPdfBytes == null) return;

    try {
      downloadPdfBytes(generatedPdfBytes!, 'report.pdf');
      _showSnackBar('PDF download started', color: Colors.green);
    } catch (e) {
      _showSnackBar('Download failed: $e', color: Colors.red);
    }
  }

  Future<void> _generateAndShareFile() async {
    if (htmlContent == null) return;
    setState(() => isLoading = true);

    try {
      final pageSize = _getEffectivePageSize();
      _showSnackBar('Generating PDF file (${pageSize.name})...',
          color: Colors.blue);

      final dir = await getApplicationDocumentsDirectory();
      final file = await _converter.convertHtmlToPdf(
        html: htmlContent!,
        targetDirectory: dir.path,
        targetName: 'report',
        options: PdfOptions(
          pageSize: pageSize,
          wrapOptions: HtmlWrapOptions(
            direction: PdfTextDirection.rtl,
            language: 'ar',
            avoidBreakInsideSelectors: [
              '.report-card',
              '.report-kv-row',
              '.report-grid-3',
            ],
          ),
        ),
      );

      setState(() => generatedPdfFilePath = file.path);
      _showSnackBar('PDF saved: ${file.path}', color: Colors.green);

      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path, mimeType: 'application/pdf')],
      ));
    } catch (e) {
      _showSnackBar('Failed: $e', color: Colors.red);
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _shareFromBytes() async {
    if (generatedPdfBytes == null) await _generatePdfBytes();
    if (generatedPdfBytes == null) return;

    try {
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/report_from_bytes.pdf');
      await tempFile.writeAsBytes(generatedPdfBytes!);
      await SharePlus.instance.share(ShareParams(
        files: [XFile(tempFile.path, mimeType: 'application/pdf')],
      ));
    } catch (e) {
      _showSnackBar('Share failed: $e', color: Colors.red);
    }
  }

  List<Widget> _buildCustomSizeInputs() {
    return [
      const SizedBox(height: 16),
      const Text('Enter custom dimensions:',
          style: TextStyle(fontWeight: FontWeight.w500)),
      const SizedBox(height: 8),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 80,
            child: TextField(
              controller: _widthController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Width',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
              onChanged: (_) => setState(() {
                generatedPdfFilePath = null;
                generatedPdfBytes = null;
              }),
            ),
          ),
          const SizedBox(width: 8),
          const Text('x'),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: TextField(
              controller: _heightController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Height',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
              onChanged: (_) => setState(() {
                generatedPdfFilePath = null;
                generatedPdfBytes = null;
              }),
            ),
          ),
          const SizedBox(width: 8),
          DropdownButton<String>(
            value: _customUnit,
            items: const [
              DropdownMenuItem(value: 'mm', child: Text('mm')),
              DropdownMenuItem(value: 'in', child: Text('inches')),
              DropdownMenuItem(value: 'pt', child: Text('points')),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _customUnit = value;
                  generatedPdfFilePath = null;
                  generatedPdfBytes = null;
                });
              }
            },
          ),
        ],
      ),
      const SizedBox(height: 8),
      Text(
        'Current: ${_getEffectivePageSize().name}',
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        scaffoldMessengerKey: _messengerKey,
        home: Scaffold(
          appBar: AppBar(
            title: const Text('Flutter Native Html to PDF'),
          ),
          body: Center(
            child: htmlContent == null
                ? const CircularProgressIndicator()
                : SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 20),
                        const Text(
                          'Select Page Size:',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        DropdownButton<String>(
                          value:
                              isCustomSize ? 'custom' : selectedPageSize.name,
                          items: const [
                            DropdownMenuItem(
                                value: 'A4', child: Text('A4 (210mm x 297mm)')),
                            DropdownMenuItem(
                                value: 'Letter',
                                child: Text('Letter (8.5" x 11")')),
                            DropdownMenuItem(
                                value: 'Legal',
                                child: Text('Legal (8.5" x 14")')),
                            DropdownMenuItem(
                                value: 'A3', child: Text('A3 (297mm x 420mm)')),
                            DropdownMenuItem(
                                value: 'A5', child: Text('A5 (148mm x 210mm)')),
                            DropdownMenuItem(
                                value: 'Tabloid',
                                child: Text('Tabloid (11" x 17")')),
                            DropdownMenuItem(
                                value: 'custom', child: Text('Custom Size...')),
                          ],
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setState(() {
                                isCustomSize = newValue == 'custom';
                                if (!isCustomSize) {
                                  selectedPageSize =
                                      _getPageSizeByName(newValue);
                                }
                                generatedPdfFilePath = null;
                                generatedPdfBytes = null;
                              });
                            }
                          },
                        ),
                        if (isCustomSize) ..._buildCustomSizeInputs(),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: isLoading ? null : _generatePdfBytes,
                          child: isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Generate PDF Bytes'),
                        ),
                        const SizedBox(height: 12),
                        if (kIsWeb)
                          ElevatedButton(
                            onPressed: isLoading ? null : _downloadPdf,
                            child: const Text('Download PDF'),
                          ),
                        if (!kIsWeb)
                          ElevatedButton(
                            onPressed: isLoading ? null : _generateAndShareFile,
                            child: const Text('Share PDF (from file)'),
                          ),
                        if (!kIsWeb) const SizedBox(height: 12),
                        if (!kIsWeb)
                          ElevatedButton(
                            onPressed: isLoading ? null : _shareFromBytes,
                            child: const Text('Share PDF (from bytes)'),
                          ),
                        const SizedBox(height: 20),
                        Text(
                          generatedPdfBytes != null
                              ? 'PDF Bytes: ${generatedPdfBytes!.length} bytes ready (${_getEffectivePageSize().name})'
                              : 'Click button to generate PDF',
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
          ),
        ));
  }
}
