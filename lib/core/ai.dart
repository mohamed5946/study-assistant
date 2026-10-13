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
        ? 'أنت مساعد مذاكرة ذكي لطالب جامعي. اشرح ببساطة وبأمثلة، وبالعربية (فصحى مبسطة). إجاباتك للمساعدة التعليمية فقط.'
        : 'You are a smart study assistant for a university student. Explain simply with examples, in English. Your answers are educational assistance only.';
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
''';
  }

  static String flashcardsPrompt({required bool ar}) {
    final lang = ar ? 'Arabic' : 'English';
    return '''
Create up to 20 flashcards from the attached PDF in $lang.
Return ONLY a JSON array, no markdown fences: [{"front":"question/prompt","back":"answer"}]
''';
  }
}
