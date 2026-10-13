import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app.dart';
import 'core/l10n.dart';
import 'core/store.dart';
import 'core/notify.dart';
import 'core/widget_service.dart';

/// Groq key baked in at build time via --dart-define (GitHub secret).
/// The key value is NEVER written in source, logs, or commits.
const _bundledGroqKey =
    String.fromEnvironment('GROQ_API_KEY', defaultValue: '');

/// On launch of a build that bundles a Groq key, auto-configure the
/// OpenAI-compatible provider when the saved key is empty OR is a stale
/// Google (Gemini) key left over from v1 — a Gemini key can never work with
/// the OpenAI-compatible provider, so that is always a misconfiguration.
/// A user-typed non-Google key is never overwritten. Idempotent.
Future<void> _applyBundledGroqKey() async {
  if (_bundledGroqKey.isEmpty) return;
  final savedKey = Settings.aiKey.trim();
  if (savedKey.isNotEmpty && !savedKey.startsWith('AIza')) return;
  Settings.aiProvider = 'openai';
  Settings.aiBaseUrl = 'https://api.groq.com/openai/v1';
  Settings.aiModel = 'openai/gpt-oss-20b';
  Settings.aiKey = _bundledGroqKey;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DB.init();
  await _applyBundledGroqKey();
  L.lang.value = Settings.lang;
  await Notify.init();
  // refresh home-screen widget with today's classes
  WidgetService.update();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  runApp(const StudyApp());
}
