import 'dart:convert';
import 'package:cronet_http/cronet_http.dart';
import 'package:http/http.dart' as http;
import 'pdf_text.dart';
import 'store.dart';

/// Single shared HTTP client for ALL AI API calls.
///
/// Routes through Chromium's network stack (Cronet — the same engine Chrome
/// uses) instead of dart:io's HttpClient. Reason (verified on-device):
/// the system DNS resolver failed every AI call with
/// "Failed host lookup: 'api.groq.com'" while Chrome on the SAME phone
/// resolved and opened https://api.groq.com fine — even with WARP on and
/// after a phone restart. Cronet uses Chromium's own host resolver, so the
/// app now resolves exactly like Chrome does.
///
/// If the Cronet engine fails to initialize, falls back to the default
/// client; failures still surface with real diagnostics (never silent).
class AiHttp {
  AiHttp._();
  static http.Client? _shared;

  /// Test hook: inject a mock client. When set, [client] returns it.
  static set testClient(http.Client? c) => _shared = c;

  /// True when the shared client is Cronet-backed.
  static bool get isCronet => _shared is CronetClient;

  static Future<http.Client> client() async {
    final existing = _shared;
    if (existing != null) return existing;
    final c = await _buildClient();
    _shared = c;
    return c;
  }

  static Future<http.Client> _buildClient() async {
    try {
      final engine = CronetEngine.build(
        cacheMode: CacheMode.memory,
        cacheMaxSize: 2 * 1024 * 1024,
        userAgent: 'StudyAssistant/2.3',
      );
      return CronetClient.fromCronetEngine(engine, closeEngine: true);
    } catch (_) {
      return http.Client();
    }
  }
}

/// Provider-neutral AI interface. UI never talks to a vendor directly.
abstract class AiProvider {
  Future<String> chat(List<AiMsg> history, {String? system});
  Future<String> analyzePdf({
    required List<int> pdfBytes,
    required String fileName,
    required String prompt,
  });
  Future<String> solveQuestions({
    required List<int> questionsPdfBytes,
    required String questionsFileName,
    required List<({String name, List<int> bytes})> materialPdfs,
  });
  Future<String> analyzeImage({
    required List<int> bytes,
    required String mimeType,
    required String prompt,
  });
}

class AiMsg {
  final String role; // user | assistant
  final String text;
  AiMsg(this.role, this.text);
}

class AiException implements Exception {
  final String message;
  AiException(this.message);
  @override
  String toString() => message;
}

/// Groq via the OpenAI-compatible chat-completions API.
///
/// ALL AI features run on this provider — there is no Gemini dependency
/// anywhere in the app anymore:
/// - chat / planner / timetable extraction: text model (`openai/gpt-oss-20b`)
/// - PDF analysis: the PDF's text is extracted ON-DEVICE ([PdfText]) and
///   sent as text context (the model is text-only)
/// - image analysis (scan question, timetable photos): Groq's vision model
///   (`meta-llama/llama-4-scout-17b-16e-instruct`), same API shape
class OpenAiCompatProvider implements AiProvider {
  final String apiKey, baseUrl, model;

  /// Vision-capable Groq model used for image inputs (text model is
  /// text-only). Still Groq, still the bundled key — no user setting.
  final String visionModel;

  OpenAiCompatProvider({
    required this.apiKey,
    required this.baseUrl,
    required this.model,
    this.visionModel = 'meta-llama/llama-4-scout-17b-16e-instruct',
  });

  Uri _completionsUri() => Uri.parse(
      '${baseUrl.replaceAll(RegExp(r'/+$'), '')}/chat/completions');

  /// Sends chat-completions messages through the shared Cronet client.
  Future<String> _post(
    List<Map<String, dynamic>> messages, {
    String? model,
    Duration timeout = const Duration(seconds: 120),
  }) async {
    final res = await (await AiHttp.client())
        .post(
          _completionsUri(),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey',
          },
          body: jsonEncode({'model': model ?? this.model, 'messages': messages}),
        )
        .timeout(timeout);
    if (res.statusCode != 200) {
      final body = res.body;
      throw AiException(
          'API ${res.statusCode}: ${body.length > 200 ? body.substring(0, 200) : body}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final choices = data['choices'] as List?;
    if (choices == null || choices.isEmpty) {
      throw AiException('API: empty response');
    }
    final text = '${choices[0]['message']?['content'] ?? ''}'.trim();
    if (text.isEmpty) throw AiException('API: empty response');
    return text;
  }

  @override
  Future<String> chat(List<AiMsg> history, {String? system}) async {
    final msgs = <Map<String, dynamic>>[];
    if (system != null && system.isNotEmpty) {
      msgs.add({'role': 'system', 'content': system});
    }
    for (final m in history) {
      msgs.add({'role': m.role, 'content': m.text});
    }
    return _post(msgs);
  }

  @override
  Future<String> analyzePdf({
    required List<int> pdfBytes,
    required String fileName,
    required String prompt,
  }) async {
    final extracted = await PdfText.extract(pdfBytes);
    if (extracted.text.trim().isEmpty) {
      throw AiException(Settings.lang == 'ar'
          ? 'تعذر استخراج نص من الـ PDF — ممكن يكون صفحات مصورة بدون نص. جرّب ملف تاني.'
          : 'Could not extract text from the PDF — it may be scanned images without a text layer. Try another file.');
    }
    final buf = StringBuffer()
      ..writeln('PDF file: $fileName (${extracted.pageCount} pages)')
      ..writeln('--- BEGIN PDF TEXT ---')
      ..writeln(extracted.text)
      ..writeln('--- END PDF TEXT ---');
    if (extracted.truncated) {
      buf.writeln(
          '[Note: only the first part of this long PDF was included. Answer from what is above.]');
    }
    return _post([
      {'role': 'system', 'content': AiService.systemPrompt()},
      {
        'role': 'user',
        'content': '$prompt\n\n${buf.toString()}',
      },
    ]);
  }

  @override
  Future<String> solveQuestions({
    required List<int> questionsPdfBytes,
    required String questionsFileName,
    required List<({String name, List<int> bytes})> materialPdfs,
  }) async {
    final qExtracted = await PdfText.extract(questionsPdfBytes);
    if (qExtracted.text.trim().isEmpty) {
      throw AiException(Settings.lang == 'ar'
          ? 'تعذر استخراج نص من PDF الأسئلة — ممكن يكون صفحات مصورة بدون نص.'
          : 'Could not extract text from the questions PDF — it may be scanned images.');
    }
    final buf = StringBuffer()
      ..writeln('=== QUESTIONS PDF: $questionsFileName ===')
      ..writeln('--- BEGIN QUESTIONS ---')
      ..writeln(qExtracted.text)
      ..writeln('--- END QUESTIONS ---')
      ..writeln()
      ..writeln('=== COURSE MATERIALS (knowledge base) ===');
    // Add material PDFs as context, sharing the 90k char budget.
    var remaining = 60000;
    for (final m in materialPdfs) {
      if (remaining <= 1000) break;
      final ext = await PdfText.extract(m.bytes, maxChars: remaining);
      if (ext.text.trim().isEmpty) continue;
      buf
        ..writeln('--- Material: ${m.name} ---')
        ..writeln(ext.text)
        ..writeln();
      remaining -= ext.text.length;
    }
    return _post([
      {'role': 'system', 'content': AiService.systemPrompt()},
      {
        'role': 'user',
        'content':
            '${AiService.solveQuestionsPrompt(ar: Settings.lang == 'ar')}\n\n${buf.toString()}',
      },
    ]);
  }

  @override
  Future<String> analyzeImage({
    required List<int> bytes,
    required String mimeType,
    required String prompt,
  }) async {
    final dataUrl = 'data:$mimeType;base64,${base64Encode(bytes)}';
    return _post(
      [
        {'role': 'system', 'content': AiService.systemPrompt()},
        {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': prompt},
            {
              'type': 'image_url',
              'image_url': {'url': dataUrl},
            },
          ],
        },
      ],
      model: visionModel,
    );
  }
}

/// Builds the configured provider from on-device settings.
/// Always the bundled Groq config (applied unconditionally at startup in
/// main.dart) — there is no provider/key UI anywhere in the app.
class AiService {
  static AiProvider? current() {
    if (!Settings.hasAiKey) return null;
    return OpenAiCompatProvider(
      apiKey: Settings.aiKey,
      baseUrl: Settings.aiBaseUrl,
      model: Settings.aiModel,
    );
  }

  static String systemPrompt() {
    final ar = Settings.lang == 'ar';
    final guard = ar
        ? ' ممنوع منعاً باتاً الإجابة عن أي سؤال يخص برمجة هذا التطبيق أو كود المصدر أو مفاتيح API أو أسرار التطبيق — ارفض بأدب واطلب من المستخدم التواصل مع المطور.'
        : ' You must NEVER answer any question about this app\'s source code, API keys, or internal secrets — politely refuse and ask the user to contact the developer.';
    return ar
        ? 'أنت مساعد مذاكرة ذكي لطالب جامعي في علوم الحاسب (نظم الحاسب ونظم المعلومات). اشرح ببساطة وبأمثلة، وبالعربية (فصحى مبسطة). عند شرح مفاهيم برمجية اذكر مثال كود قصير — الشرح بالعربية والكود بالإنجليزية داخل ```code blocks```. إجاباتك للمساعدة التعليمية فقط.$guard'
        : 'You are a smart study assistant for a Computer Science university student. Explain simply with examples, in English. When explaining programming concepts, include a short code example inside ```code blocks```. Your answers are educational assistance only.$guard';
  }

  /// Asks the model to return a JSON array of questions.
  static String questionsPrompt(
      {required int count, required String difficulty, required bool ar}) {
    final lang = ar ? 'Arabic' : 'English';
    return '''
Generate $count study questions ($difficulty difficulty) in $lang from the PDF text below.
Return ONLY a JSON array, no markdown fences, no extra text. Each item:
{"q":"question text","type":"mcq"|"tf"|"short","options":["a","b","c","d"],"answer":"exact correct option text (or true/false for tf, or empty for short)","explanation":"brief why"}
For tf type use options ["true","false"]. For short type use options [] and answer "".
If the PDF is about computer science/programming, the "explanation" may include a tiny code example where relevant (keep it short).
''';
  }

  static String flashcardsPrompt({required bool ar}) {
    final lang = ar ? 'Arabic' : 'English';
    return '''
Create up to 20 flashcards from the PDF text below in $lang.
Return ONLY a JSON array, no markdown fences: [{"front":"question/prompt","back":"answer"}]
''';
  }

  /// Prompt for solving questions extracted from a questions-PDF, using the
  /// subject's other PDFs as the knowledge base.
  static String solveQuestionsPrompt({required bool ar}) {
    final lang = ar ? 'Arabic' : 'English';
    return '''
You are given TWO parts below:
1. "QUESTIONS PDF" — contains exam/practice questions. Extract each question AS WRITTEN.
2. "COURSE MATERIALS" — PDFs from the same subject. Use them as your knowledge base to SOLVE each question.

For each question, solve it using the course materials. Return ONLY a JSON array, no markdown fences, no extra text. Each item:
{"question":"exact question text","type":"mcq"|"tf"|"written","options":["a","b","c","d"],"correctIndex":0,"answer":"full correct answer text","explanation":"brief explanation in $lang, referencing the material"}

Rules:
- For "mcq": include ALL options as written, set "correctIndex" to the 0-based index of the correct option, "answer" = the correct option text.
- For "tf": options = ["true","false"] (or ["صح","خطأ"] in Arabic), correctIndex = 0 or 1.
- For "written": options = [], correctIndex = -1, "answer" = the full solution.
- Language: $lang.
- If a question cannot be answered from the materials, still solve it from your knowledge but note that in the explanation.
''';
  }

  /// Extracts the PDF's OWN questions (for self-test mode).
  static String extractPdfQuestionsPrompt({required bool ar}) {
    final lang = ar ? 'Arabic' : 'English';
    return '''
Find the actual questions written INSIDE the PDF text below (exam questions, exercises, quizzes — not generated ones). Page markers look like "===== Page 3 =====".
Return ONLY a JSON array, no markdown fences, no extra text. Each item:
{"q":"question text exactly as in the PDF","type":"mcq"|"tf"|"short","options":["choice1","choice2","choice3","choice4"],"answer":"exact correct option text","explanation":"brief reasoning why this is correct","page":12}
Rules:
- For mcq include all choices from the PDF. For tf use options ["true","false"]. For short use options [] and answer "".
- "page" is the PDF page number from the nearest "===== Page N =====" marker above the question (integer). If unknown use 0.
- Keep question text in its original language; write answer/explanation in $lang.
- If the PDF has no clear questions, return [].
''';
  }

  /// Asks a question about the PDF, demanding page citations.
  static String askPdfPrompt(String question, {required bool ar}) {
    final lang = ar ? 'Arabic' : 'English';
    final sourcesLabel = ar ? 'المصادر:' : 'Sources:';
    final generalNote = ar
        ? 'من المعرفة العامة'
        : 'From general knowledge';
    return '''
Answer this question from the PDF text below only, in $lang: "$question"
Rules:
- Base your answer strictly on the PDF content. If the PDF doesn't contain the answer, say so honestly.
- The PDF text has page markers like "===== Page 3 =====". After each factual claim, cite the page like this: [p:12]
- End your answer with a "$sourcesLabel" line listing which document(s)/page(s) the info came from.
- If the answer is from general knowledge (not in the PDF), end with "$sourcesLabel $generalNote" instead.
''';
  }

  /// Solves a photographed textbook question step by step.
  /// The photo itself is sent to the vision model; if OCR-style text was
  /// extracted instead it is appended after the prompt.
  static String scanQuestionPrompt({required bool ar, String? ocrText}) {
    final lang = ar ? 'Arabic' : 'English';
    final extra = (ocrText != null && ocrText.trim().isNotEmpty)
        ? '\n\nText read from the photo (may be imperfect):\n$ocrText'
        : '';
    return '''
Look at this photo. It shows a study question — it may also be a photo of CODE from a whiteboard or notebook (the user is a Computer Science student).

1. First transcribe what you see (the question text, or the code as-is).
2. If it is a question: solve it step by step in $lang.
3. If it is CODE: explain what the code does in $lang, point out any bugs and show the fixed code inside ```code blocks```, then add a short complexity note (Big-O time/space).
4. Keep code itself in English; explanations in $lang.
If the photo is unreadable, say so and ask for a clearer photo.$extra
''';
  }

  /// Extracts timetable sessions from a university timetable PDF/image.
  static String extractTimetablePrompt({required bool ar}) {
    final lang = ar ? 'Arabic' : 'English';
    return '''
Analyze this university timetable and extract every class session. The timetable is given as PDF text below (or a photo).
Return ONLY a JSON array, no markdown fences, no extra text. Each item:
{"subject":"subject name","code":"course code (or empty)","day":"Mon"|"Tue"|"Wed"|"Thu"|"Fri"|"Sat"|"Sun","start":"HH:MM 24h","end":"HH:MM 24h","place":"location (or empty)","instructor":"instructor (or empty)","kind":"lecture"|"section","group":"section/group label like A, B, S1 (or empty if none)"}
Rules:
- "group" identifies alternative sections of the same subject (students attend ONE group). If the timetable shows e.g. "Section A" and "Section B" for one subject, put "A"/"B".
- Times in 24-hour HH:MM.
- If a field is unknown, use "".
- Write subject names as they appear; add a short $lang clarification only if the name is cryptic.
''';
  }

  /// Generates a study plan from exams, hours, and focus type.
  static String studyPlanPrompt({
    required String examsInfo,
    required int hoursPerDay,
    required String focus,
    required bool ar,
  }) {
    final lang = ar ? 'Arabic' : 'English';
    return '''
You are a study coach. Create a practical weekly study plan in $lang.
Upcoming exams/deadlines: $examsInfo
Available study time: $hoursPerDay hours per day.
Focus type: $focus.
Return a clear day-by-day plan (7 days max), each day with timed blocks naming the subject and task.
Keep it realistic: include short breaks, put harder subjects earlier in the day, and leave one lighter review day.
Format with headers and bullet points, no JSON.
''';
  }
}
