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

/// On first launch of a build that bundles a Groq key (and only if the
/// user hasn't saved his own key), auto-configure the OpenAI-compatible
/// provider with the free Groq endpoint. A manually entered key always
/// wins — this runs exactly once.
Future<void> _applyBundledGroqKey() async {
  if (_bundledGroqKey.isEmpty) return;
  if (DB.kv.get('bundledKeyApplied', defaultValue: false) as bool) return;
  if (Settings.aiKey.trim().isEmpty) {
    Settings.aiProvider = 'openai';
    Settings.aiBaseUrl = 'https://api.groq.com/openai/v1';
    Settings.aiModel = 'openai/gpt-oss-20b';
    Settings.aiKey = _bundledGroqKey;
  }
  await DB.kv.put('bundledKeyApplied', true);
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
