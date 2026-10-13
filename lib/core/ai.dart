import 'dart:convert';
import 'package:http/http.dart' as http;
import 'store.dart';

/// Provider-neutral AI interface. UI never talks to a vendor directly.
abstract class AiProvider {
  Future<String> chat(List<AiMsg> history, {String? system});
  Future<String> analyzePdf({
    required List<int> pdfBytes,
    required String fileName,
    required String prompt,
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

/// Google Gemini via AI Studio (free tier). Supports native PDF input.
/// Verified working: model `gemini-3.8-flash`, auth via `X-goog-api-key` header.
/// Free tier may return 503 under high demand -> retried with backoff.
class GeminiProvider implements AiProvider {
  final String apiKey;
  final String model;
  GeminiProvider({required this.apiKey, required this.model});

  Uri _uri() => Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent');

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'X-goog-api-key': apiKey,
      };

  static const _retryDelays = [
    Duration(seconds: 2),
    Duration(seconds: 5),
    Duration(seconds: 10),
  ];

  Future<String> _post(Map<String, dynamic> body) async {
    for (var attempt = 0; ; attempt++) {
      http.Response res;
      try {
        res = await http
            .post(_uri(), headers: _headers, body: jsonEncode(body))
            .timeout(const Duration(seconds: 90));
      } catch (e) {
        throw AiException(_friendlyError(-1, ''));
      }
      if (res.statusCode == 200) return _parse(res.body);
      if (res.statusCode == 503 && attempt < _retryDelays.length) {
        await Future.delayed(_retryDelays[attempt]);
        continue;
      }
      throw AiException(_friendlyError(res.statusCode, res.body));
    }
  }

  String _parse(String body) {
    final data = jsonDecode(body) as Map<String, dynamic>;
    final cands = data['candidates'] as List?;
    if (cands == null || cands.isEmpty) {
      throw AiException(_friendlyError(-2, ''));
    }
    final parts = (cands[0]['content']?['parts'] as List?) ?? const [];
    final text = parts.map((p) => '${p['text'] ?? ''}').join('\n').trim();
    if (text.isEmpty) throw AiException(_friendlyError(-2, ''));
    return text;
  }

  String _friendlyError(int code, String body) {
    final ar = Settings.lang == 'ar';
    if (code == 503) {
      return ar
          ? 'الخدمة مشغولة دلوقتي، حاول تاني بعد شوية 🔄'
          : 'The service is busy right now, please try again shortly 🔄';
    }
    if (code == -1) {
      return ar
          ? 'مفيش اتصال بالإنترنت. اتأكد من النت وحاول تاني.'
          : 'No internet connection. Check and retry.';
    }
    if (code == -2) {
      return ar
          ? 'الـ AI مرجعش إجابة. حاول تاني.'
          : 'The AI returned no answer. Try again.';
    }
    String detail = '';
    try {
      detail = (jsonDecode(body) as Map)['error']?['message'] ?? '';
    } catch (_) {}
    if (code == 400 && detail.contains('API key')) {
      return ar
          ? 'مفتاح الـ API مش صحيح. اتأكد منه في الإعدادات.'
          : 'Invalid API key. Check it in Settings.';
    }
    return 'Gemini $code: $detail';
  }

  @override
  Future<String> chat(List<AiMsg> history, {String? system}) async {
    final contents = <Map<String, dynamic>>[];
    if (system != null && system.isNotEmpty) {
      contents.add({
        'role': 'user',
        'parts': [
          {'text': 'System instruction: $system'}
        ]
      });
    }
    for (final m in history) {
      contents.add({
        'role': m.role == 'assistant' ? 'model' : 'user',
        'parts': [
          {'text': m.text}
        ]
      });
    }
    return _post({'contents': contents});
  }

  @override
  Future<String> analyzePdf({
    required List<int> pdfBytes,
    required String fileName,
    required String prompt,
  }) async {
    return _post({
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': prompt},
            {
              'inlineData': {
                'mimeType': 'application/pdf',
                'data': base64Encode(pdfBytes),
              }
            },
          ]
        }
      ]
    });
  }

  /// Sends an image (photo of a question / timetable) to Gemini.
  @override
  Future<String> analyzeImage({
    required List<int> bytes,
    required String mimeType,
    required String prompt,
  }) async {
    return _post({
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': prompt},
            {
              'inlineData': {
                'mimeType': mimeType,
                'data': base64Encode(bytes),
              }
            },
          ]
        }
      ]
    });
  }
}

/// Any OpenAI-compatible chat completions endpoint.
class OpenAiCompatProvider implements AiProvider {
  final String apiKey, baseUrl, model;
  OpenAiCompatProvider(
      {required this.apiKey, required this.baseUrl, required this.model});

  @override
  Future<String> chat(List<AiMsg> history, {String? system}) async {
    final msgs = <Map<String, String>>[];
    if (system != null && system.isNotEmpty) {
      msgs.add({'role': 'system', 'content': system});
    }
    for (final m in history) {
      msgs.add({'role': m.role, 'content': m.text});
    }
    final url = Uri.parse('${baseUrl.replaceAll(RegExp(r'/+$'), '')}/chat/completions');
    final res = await http
        .post(url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: jsonEncode({'model': model, 'messages': msgs}))
        .timeout(const Duration(seconds: 90));
    if (res.statusCode != 200) {
      throw AiException('API ${res.statusCode}: ${res.body.length > 200 ? res.body.substring(0, 200) : res.body}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final choices = data['choices'] as List?;
    if (choices == null || choices.isEmpty) {
      throw AiException('API: empty response');
    }
    return '${choices[0]['message']?['content'] ?? ''}'.trim();
  }

  @override
  Future<String> analyzePdf({
    required List<int> pdfBytes,
    required String fileName,
    required String prompt,
  }) {
    throw AiException('PDF_ANALYSIS_NEEDS_GEMINI');
  }

  @override
  Future<String> analyzeImage({
    required List<int> bytes,
    required String mimeType,
    required String prompt,
  }) {
    throw AiException('IMAGE_ANALYSIS_NEEDS_GEMINI');
  }
}

/// Builds the configured provider from on-device settings.
class AiService {
  static AiProvider? current() {
    if (!Settings.hasAiKey) return null;
    if (Settings.aiProvider == 'gemini') {
      return GeminiProvider(apiKey: Settings.aiKey, model: Settings.aiModel);
    }
    return OpenAiCompatProvider(
      apiKey: Settings.aiKey,
      baseUrl: Settings.aiBaseUrl,
      model: Settings.aiModel,
    );
  }

  static String systemPrompt() {
    final ar = Settings.lang == 'ar';
    return ar
        ? 'أنت مساعد مذاكرة ذكي لطالب جامعي في علوم الحاسب (نظم الحاسب ونظم المعلومات). اشرح ببساطة وبأمثلة، وبالعربية (فصحى مبسطة). عند شرح مفاهيم برمجية اذكر مثال كود قصير — الشرح بالعربية والكود بالإنجليزية داخل ```code blocks```. إجاباتك للمساعدة التعليمية فقط.'
        : 'You are a smart study assistant for a Computer Science university student. Explain simply with examples, in English. When explaining programming concepts, include a short code example inside ```code blocks```. Your answers are educational assistance only.';
  }

  /// Asks the model to return a JSON array of questions.
  static String questionsPrompt(
      {required int count, required String difficulty, required bool ar}) {
    final lang = ar ? 'Arabic' : 'English';
    return '''
Generate $count study questions ($difficulty difficulty) in $lang from the attached PDF.
Return ONLY a JSON array, no markdown fences, no extra text. Each item:
{"q":"question text","type":"mcq"|"tf"|"short","options":["a","b","c","d"],"answer":"exact correct option text (or true/false for tf, or empty for short)","explanation":"brief why"}
For tf type use options ["true","false"]. For short type use options [] and answer "".
If the PDF is about computer science/programming, the "explanation" may include a tiny code example where relevant (keep it short).
''';
  }

  static String flashcardsPrompt({required bool ar}) {
    final lang = ar ? 'Arabic' : 'English';
    return '''
Create up to 20 flashcards from the attached PDF in $lang.
Return ONLY a JSON array, no markdown fences: [{"front":"question/prompt","back":"answer"}]
''';
  }

  /// Extracts the PDF's OWN questions (for self-test mode).
  static String extractPdfQuestionsPrompt({required bool ar}) {
    final lang = ar ? 'Arabic' : 'English';
    return '''
Find the actual questions written INSIDE the attached PDF (exam questions, exercises, quizzes — not generated ones).
Return ONLY a JSON array, no markdown fences, no extra text. Each item:
{"q":"question text exactly as in the PDF","type":"mcq"|"tf"|"short","options":["choice1","choice2","choice3","choice4"],"answer":"exact correct option text","explanation":"brief reasoning why this is correct","page":12}
Rules:
- For mcq include all choices from the PDF. For tf use options ["true","false"]. For short use options [] and answer "".
- "page" is the PDF page number where the question appears (integer). If unknown use 0.
- Keep question text in its original language; write answer/explanation in $lang.
- If the PDF has no clear questions, return [].
''';
  }

  /// Asks a question about the PDF, demanding page citations.
  static String askPdfPrompt(String question, {required bool ar}) {
    final lang = ar ? 'Arabic' : 'English';
    return '''
Answer this question from the attached PDF only, in $lang: "$question"
Rules:
- Base your answer strictly on the PDF content. If the PDF doesn't contain the answer, say so honestly.
- After each factual claim, cite the page like this: [p:12]
- End your answer with a "Sources:" line listing the cited pages.
''';
  }

  /// Solves a photographed textbook question step by step.
  static String scanQuestionPrompt({required bool ar}) {
    final lang = ar ? 'Arabic' : 'English';
    return '''
Look at this photo. It shows a study question — it may also be a photo of CODE from a whiteboard or notebook (the user is a Computer Science student).

1. First transcribe what you see (the question text, or the code as-is).
2. If it is a question: solve it step by step in $lang.
3. If it is CODE: explain what the code does in $lang, point out any bugs and show the fixed code inside ```code blocks```, then add a short complexity note (Big-O time/space).
4. Keep code itself in English; explanations in $lang.
If the photo is unreadable, say so and ask for a clearer photo.
''';
  }

  /// Extracts timetable sessions from a university timetable PDF/image.
  static String extractTimetablePrompt({required bool ar}) {
    final lang = ar ? 'Arabic' : 'English';
    return '''
Analyze this university timetable (PDF or image) and extract every class session.
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
