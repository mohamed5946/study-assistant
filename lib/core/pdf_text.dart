import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'ocr.dart';

/// Result of on-device PDF text extraction.
class PdfExtractResult {
  /// Plain text of the (possibly truncated) document. Pages are separated by
  /// `===== Page N =====` markers so the AI can cite page numbers.
  final String text;
  final int pageCount;
  final bool truncated;

  /// True when the text came from OCR (scanned pages) instead of the PDF's
  /// embedded text layer — callers should warn that it may contain errors.
  final bool usedOcr;
  const PdfExtractResult({
    required this.text,
    required this.pageCount,
    required this.truncated,
    this.usedOcr = false,
  });
}

/// Extracts text from a PDF fully on-device (no network). Used to feed PDF
/// content to the Groq (OpenAI-compatible, text-only) model.
class PdfText {
  /// Upper bound on characters sent to the AI. gpt-oss-20b has a large
  /// context window; 90k chars keeps requests fast and cheap.
  static const int maxChars = 90000;

  /// Extracts text page by page, in order, stopping at [maxChars].
  ///
  /// If the PDF has no embedded text layer (scanned images) and
  /// [tryOcrFallback] is true, falls back to on-device Tesseract OCR.
  /// [onOcrProgress] reports (done, total) during the OCR pass.
  static Future<PdfExtractResult> extract(
    List<int> bytes, {
    int maxChars = PdfText.maxChars,
    bool tryOcrFallback = true,
    void Function(int done, int total)? onOcrProgress,
  }) async {
    final doc = PdfDocument(inputBytes: bytes);
    try {
      final extractor = PdfTextExtractor(doc);
      final buf = StringBuffer();
      var truncated = false;
      final n = doc.pages.count;
      for (var i = 0; i < n; i++) {
        final pageText =
            extractor.extractText(startPageIndex: i, endPageIndex: i);
        final marker = '\n\n===== Page ${i + 1} =====\n\n';
        final chunk = '$marker$pageText';
        if (buf.length + chunk.length > maxChars) {
          final remaining = maxChars - buf.length;
          if (remaining > marker.length + 20) {
            buf.write(marker);
            buf.write(pageText.substring(0, remaining - marker.length));
          }
          truncated = true;
          break;
        }
        buf.write(chunk);
      }
      final text = buf.toString().trim();
      // Scanned PDF: no (or almost no) embedded text → try OCR.
      if (text.length < 50 && tryOcrFallback) {
        try {
          final ocrText = await Ocr.extractFromPdf(
            bytes,
            onProgress: onOcrProgress,
          );
          if (ocrText.isNotEmpty) {
            final clipped = ocrText.length > maxChars
                ? ocrText.substring(0, maxChars)
                : ocrText;
            return PdfExtractResult(
              text: clipped,
              pageCount: n,
              truncated: ocrText.length > maxChars,
              usedOcr: true,
            );
          }
        } catch (_) {
          // OCR failed — fall through and return the (empty) text result.
        }
      }
      return PdfExtractResult(
        text: text,
        pageCount: n,
        truncated: truncated || buf.length >= maxChars,
      );
    } finally {
      doc.dispose();
    }
  }
}
