import 'package:flutter/material.dart';
import '../core/ai.dart';
import '../core/l10n.dart';
import '../core/notify.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../core/widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _keyC, _baseC, _modelC, _focusC, _breakC, _thrC;
  bool _obscure = true;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    _keyC = TextEditingController(text: Settings.aiKey);
    _baseC = TextEditingController(text: Settings.aiBaseUrl);
    _modelC = TextEditingController(text: Settings.aiModel);
    _focusC = TextEditingController(text: '${Settings.focusMin}');
    _breakC = TextEditingController(text: '${Settings.breakMin}');
    _thrC = TextEditingController(text: '${Settings.attendanceThreshold}');
  }

  @override
  void dispose() {
    _keyC.dispose();
    _baseC.dispose();
    _modelC.dispose();
    _focusC.dispose();
    _breakC.dispose();
    _thrC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isGemini = Settings.aiProvider == 'gemini';
    return Scaffold(
      appBar: AppBar(title: Text(t('settings'))),
      body: AuroraBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          children: [
            SectionHeader(title: t('language')),
            GlassCard(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: RadioGroup<String>(
                groupValue: L.lang.value,
                onChanged: (v) {
                  if (v == null) return;
                  L.lang.value = v;
                  Settings.lang = v;
                  setState(() {});
                },
                child: const Column(
                  children: [
                    RadioListTile<String>(
                      value: 'ar',
                      title: Text('العربية'),
                    ),
                    RadioListTile<String>(
                      value: 'en',
                      title: Text('English'),
                    ),
                  ],
                ),
              ),
            ),
            SectionHeader(title: t('theme')),
            GlassCard(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: RadioGroup<String>(
                groupValue: Settings.theme,
                onChanged: (v) {
                  if (v == null) return;
                  Settings.theme = v;
                  setState(() {});
                },
                child: Column(
                  children: [
                    for (final m in ['system', 'light', 'dark'])
                      RadioListTile<String>(
                        value: m,
                        title: Text(t('${m}Theme')),
                      ),
                  ],
                ),
              ),
            ),
            SectionHeader(title: t('aiProvider')),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedButton<String>(
                    segments: [
                      ButtonSegment(
                          value: 'gemini', label: Text(t('gemini'))),
                      ButtonSegment(
                          value: 'openai',
                          label: Text(t('openAiCompat'))),
                    ],
                    selected: {Settings.aiProvider},
                    onSelectionChanged: (s) {
                      Settings.aiProvider = s.first;
                      if (s.first == 'gemini' &&
                          (_modelC.text.contains('gpt') ||
                              _modelC.text.contains('2.0-flash'))) {
                        _modelC.text = 'gemini-3.8-flash';
                        Settings.aiModel = _modelC.text;
                      } else if (s.first == 'openai') {
                        // pre-fill free Groq defaults (key is never embedded)
                        if (_baseC.text.trim().isEmpty ||
                            _baseC.text.contains('openai.com')) {
                          _baseC.text =
                              'https://api.groq.com/openai/v1';
                          Settings.aiBaseUrl = _baseC.text;
                        }
                        if (_modelC.text.trim().isEmpty ||
                            _modelC.text.contains('gemini')) {
                          _modelC.text = 'openai/gpt-oss-20b';
                          Settings.aiModel = _modelC.text;
                        }
                      }
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _keyC,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: t('apiKey'),
                      prefixIcon:
                          const Icon(Icons.key_rounded),
                      suffixIcon: IconButton(
                        icon: Icon(_obscure
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_rounded),
                        onPressed: () =>
                            setState(() => _obscure = !_obscure),
                      ),
                    ),
                    onChanged: (v) => Settings.aiKey = v.trim(),
                  ),
                  const SizedBox(height: 6),
                  Text(t('keySavedOnDevice'),
                      style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant)),
                  if (!isGemini) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: _baseC,
                      decoration: InputDecoration(
                          labelText: t('baseUrl')),
                      onChanged: (v) =>
                          Settings.aiBaseUrl = v.trim(),
                    ),
                  ],
                  const SizedBox(height: 10),
                  TextField(
                    controller: _modelC,
                    decoration:
                        InputDecoration(labelText: t('model')),
                    onChanged: (v) =>
                        Settings.aiModel = v.trim(),
                  ),
                  if (!isGemini) ...[
                    const SizedBox(height: 6),
                    Text(t('groqHint'),
                        style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant)),
                  ],
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: _testing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2))
                        : const Icon(Icons.bolt_rounded),
                    label: Text(t('testConnection')),
                    onPressed: _testing ? null : _test,
                  ),
                ],
              ),
            ),
            SectionHeader(title: t('pomodoro')),
            GlassCard(
              child: Row(
                children: [
                  Expanded(
                      child: TextField(
                          controller: _focusC,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                              labelText: t('focusMin')),
                          onChanged: (v) {
                            final n = int.tryParse(v);
                            if (n != null && n > 0) {
                              Settings.focusMin = n;
                            }
                          })),
                  const SizedBox(width: 10),
                  Expanded(
                      child: TextField(
                          controller: _breakC,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                              labelText: t('breakMin')),
                          onChanged: (v) {
                            final n = int.tryParse(v);
                            if (n != null && n > 0) {
                              Settings.breakMin = n;
                            }
                          })),
                ],
              ),
            ),
            SectionHeader(title: t('attendance')),
            GlassCard(
              child: TextField(
                controller: _thrC,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                    labelText: '${t('warningThreshold')} %'),
                onChanged: (v) {
                  final n = int.tryParse(v);
                  if (n != null && n >= 0 && n <= 100) {
                    Settings.attendanceThreshold = n;
                  }
                },
              ),
            ),
            SectionHeader(title: t('about')),
            GlassCard(child: Text(t('aboutText'))),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.notifications_rounded),
              label: Text(t('reminder')),
              onPressed: () async {
                final ok = await Notify.requestPermission();
                if (!context.mounted) return;
                if (!ok) {
                  showSnack(context, t('permNeeded'), error: true);
                } else {
                  showSnack(context, '✅');
                }
              },
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error),
              icon: const Icon(Icons.delete_forever_rounded),
              label: Text(t('clearData')),
              onPressed: () async {
                if (await confirmDelete(context,
                    message: t('clearDataMsg'))) {
                  await DB.clearAll();
                  if (context.mounted) {
                    showSnack(context, '✅');
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _test() async {
    if (_keyC.text.trim().isEmpty) {
      showSnack(context, t('noApiKeyMsg'), error: true);
      return;
    }
    setState(() => _testing = true);
    String msg;
    bool isError;
    try {
      final p = AiService.current();
      final reply = await p!.chat(
          [AiMsg('user', Settings.lang == 'ar' ? 'قول: تمام' : 'Say: ok')],
          system: '');
      msg = reply.isNotEmpty ? t('connectionOk') : t('connectionFail');
      isError = reply.isEmpty;
    } catch (_) {
      msg = t('connectionFail');
      isError = true;
    }
    if (mounted) {
      showSnack(context, msg, error: isError);
      setState(() => _testing = false);
    }
  }
}
