import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:study_assistant/core/pdf_text.dart';

/// Regression tests for the v2.3 change: PDF analysis moved from a
/// Gemini-only gate to on-device text extraction fed to Groq.
void main() {
  Future<Uint8List> makePdf(List<String> pageTexts) async {
    final doc = PdfDocument();
    for (final t in pageTexts) {
      doc.pages.add().graphics.drawString(
          t, PdfStandardFont(PdfFontFamily.helvetica, 14));
    }
    final bytes = Uint8List.fromList(doc.saveSync());
    doc.dispose();
    return bytes;
  }

  test('extracts text page by page with page markers', () async {
    final bytes = await makePdf(['alpha lecture notes', 'beta lab work']);
    final r = await PdfText.extract(bytes);
    expect(r.pageCount, 2);
    expect(r.truncated, isFalse);
    expect(r.text, contains('alpha lecture notes'));
    expect(r.text, contains('beta lab work'));
    expect(r.text, contains('===== Page 1 ====='));
    expect(r.text, contains('===== Page 2 ====='));
  });

  test('truncates long documents and flags it', () async {
    final big = 'word ' * 30000; // ~150k chars
    final bytes = await makePdf([big]);
    final r = await PdfText.extract(bytes, maxChars: 1000);
    expect(r.truncated, isTrue);
    expect(r.text.length, lessThanOrEqualTo(1000));
  });

  test('corrupt input throws a catchable error', () async {
    expect(() => PdfText.extract(Uint8List.fromList([1, 2, 3])),
        throwsA(anything));
  });
}
