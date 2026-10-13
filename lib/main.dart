import 'package:flutter/material.dart';
import 'app.dart';
import 'core/l10n.dart';
import 'core/store.dart';
import 'core/notify.dart';
import 'core/widget_service.dart';

/// Groq key baked in at build time via --dart-define (GitHub secret).
/// The key value is NEVER written in source, logs, or commits.
const _bundledGroqKey =
    String.fromEnvironment('GROQ_API_KEY', defaultValue: '');

/// The bundled Groq key (injected at build time via --dart-define from the
/// CI secret) is the single source of AI config — there is no key UI.
/// Applied on every launch so the assistant always just works.
Future<void> _applyBundledGroqKey() async {
  if (_bundledGroqKey.isEmpty) return;
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
  runApp(const StudyApp());
}
