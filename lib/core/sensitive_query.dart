/// Local gate for questions about this app itself.
///
/// The AI must never answer questions about the app's source code, how it
/// was built, or its internal details. Those questions are intercepted
/// before they reach the AI and answered with the "contact the developer"
/// popup instead.
///
/// Rules (case-insensitive `contains`, like the original gate):
/// - Every legacy pattern is kept verbatim.
/// - New "about this app" phrasings are blocked.
/// - The words for "code" (كود / code) and "source" (سورس / source) only
///   block when combined with an app word (البرنامج / التطبيق / app).
///   A bare code-help question ("اشرح الكود ده", "explain this code")
///   must keep working — it has no app word in it.
bool isSensitiveAppQuery(String text) {
  final lower = text.toLowerCase();
  if (_directPatterns.any((p) => lower.contains(p.toLowerCase()))) {
    return true;
  }
  final hasAppWord = _appWords.any((w) => lower.contains(w.toLowerCase()));
  if (!hasAppWord) return false;
  return _codeWords.any((w) => lower.contains(w.toLowerCase()));
}

/// Suggested prompts are visible only while the user has typed nothing.
bool promptsVisibleForInput(String text) => text.trim().isEmpty;

const _directPatterns = [
  // Legacy patterns (kept verbatim).
  'source code',
  'سورس كود',
  'كود المصدر',
  'كود البرنامج',
  'كود التطبيق',
  'api key',
  'apikey',
  'مفتاح الـapi',
  'مفتاح api',
  'decompile',
  'فك التطبيق',
  'هندسة عكسية',
  'reverse engineer',
  'app secret',
  'سر التطبيق',
  'groq key',
  'مفتاح groq',
  // New: "make a program like this" and "details about this app".
  'اعمل برنامج زي',
  'اعمل تطبيق زي',
  'عايز اعمل برنامج',
  'برنامج زي ده',
  'برنامج زي هذا',
  'تطبيق زي ده',
  'نسخة من البرنامج',
  'نسخة من التطبيق',
  'تفاصيل البرنامج',
  'معلومات عن البرنامج',
  'معلومات عن التطبيق',
  'تفاصيل التطبيق',
  'معلومات مفصلة عن البرنامج',
  'ازاي البرنامج اتعمل',
  'ازاي اتعمل البرنامج',
  'ازاي عملت البرنامج',
  'ازاي عملت التطبيق',
  'التطبيق ده اتعمل',
  'كيف تم بناء',
  'how was this app built',
  'how this app was made',
  'how was this app created',
  'how did you build this app',
  'make an app like this',
  'build an app like this',
  'clone this app',
  'copy this app',
  'app details',
  'details about this app',
  'information about this app',
  'app information',
];

const _appWords = [
  'البرنامج',
  'التطبيق',
  'app',
];

const _codeWords = [
  'كود',
  'code',
  'سورس',
  'source',
];
