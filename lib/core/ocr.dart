import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';

/// On-device OCR for scanned PDFs (no text layer) using Tesseract.
/// Supports Arabic + English via bundled traineddata (assets/tessdata/).
class Ocr {
  /// Renders up to [maxPages] PDF pages to images and runs Tesseract OCR.
  ///
  /// Returns page-separated text with `===== Page N (OCR) =====` markers,
  /// matching the style of [PdfText] so AI prompts stay consistent.
  /// Throws on failure — callers should catch and degrade gracefully.
  static Future<String> extractFromPdf(
    List<int> pdfBytes, {
    int maxPages = 10,
    void Function(int done, int total)? onProgress,
  }) async {
    final doc = await PdfDocument.openData(Uint8List.fromList(pdfBytes));
    try {
      final total = doc.pagesCount;
      final n = total < maxPages ? total : maxPages;
      final buf = StringBuffer();
      final tmp = await getTemporaryDirectory();
      for (var i = 1; i <= n; i++) {
        final page = await doc.getPage(i);
        try {
          // Render at 2x for sharper OCR input.
          final img = await page.render(
            width: page.width * 2,
            height: page.height * 2,
            format: PdfPageImageFormat.png,
          );
          final bytes = img?.bytes;
          if (bytes == null || bytes.isEmpty) continue;
          final imgFile =
              File('${tmp.path}/ocr_page_$i.png');
          await imgFile.writeAsBytes(bytes, flush: true);
          final text = await FlutterTesseractOcr.extractText(
            imgFile.path,
            language: 'ara+eng',
            args: {
              'psm': '4',
              'preserve_interword_spaces': '1',
            },
          );
          // Clean up the temp image right away to save disk.
          try {
            await imgFile.delete();
          } catch (_) {}
          final clean = text.trim();
          if (clean.isNotEmpty) {
            buf.writeln('\n\n===== Page $i (OCR) =====\n');
            buf.writeln(clean);
          }
        } finally {
          await page.close();
        }
        onProgress?.call(i, n);
      }
      return buf.toString().trim();
    } finally {
      await doc.close();
    }
  }
}
