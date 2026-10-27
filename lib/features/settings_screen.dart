import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../core/ai.dart';
import '../core/book_loader.dart';
import '../core/glass_dialog.dart';
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
  late TextEditingController _focusC, _breakC, _longBreakC, _thrC;
  bool _testing = false;
  String _version = '';

  @override
  void initState() {
    super.initState();
    _focusC = TextEditingController(text: '${Settings.focusMin}');
    _breakC = TextEditingController(text: '${Settings.breakMin}');
    _longBreakC =
        TextEditingController(text: '${Settings.longBreakMin}');
    _thrC = TextEditingController(text: '${Settings.attendanceThreshold}');
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = info.version);
    });
  }

  @override
  void dispose() {
    _focusC.dispose();
    _breakC.dispose();
    _longBreakC.dispose();
    _thrC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
            SectionHeader(title: t('reduceAnimations')),
            GlassCard(
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.motion_photos_off_rounded,
                        color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(t('reduceAnimationsHint'))),
                  const SizedBox(width: 8),
                  Switch(
                    value: Settings.reduceAnim,
                    onChanged: (v) {
                      Settings.reduceAnim = v;
                      setState(() {});
                    },
                  ),
                ],
              ),
            ),
            SectionHeader(title: t('aiStatus')),
            GlassCard(
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.psychology_rounded,
                        color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(t('aiReady'))),
                  const SizedBox(width: 8),
                  _testing
                      ? const BookLoader(size: 30)
                      : OutlinedButton.icon(
                          icon: const Icon(Icons.bolt_rounded, size: 18),
                          label: Text(t('checkNow')),
                          onPressed: _test,
                        ),
                ],
              ),
            ),
            SectionHeader(title: t('pomodoro')),
            GlassCard(
              child: Column(
                children: [
                  Row(
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
                  const SizedBox(height: 10),
                  TextField(
                      controller: _longBreakC,
                      keyboardType: TextInputType.number,
                      decoration:
                          InputDecoration(labelText: t('longBreakMin')),
                      onChanged: (v) {
                        final n = int.tryParse(v);
                        if (n != null && n > 0) {
                          Settings.longBreakMin = n;
                        }
                      }),
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
            GlassCard(
              child: Text(
                _version.isEmpty
                    ? t('aboutText')
                    : '${t('appName')} v$_version — ${t('aboutText')}',
              ),
            ),
            SectionHeader(title: t('contact')),
            GlassCard(
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => _showContact(context),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color:
                              AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.contact_support_rounded,
                            color: AppColors.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(t('contact'))),
                      const Icon(Icons.chevron_left_rounded,
                          color: AppColors.primary),
                    ],
                  ),
                ),
              ),
            ),
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
                if (await confirmDelete(context)) {
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

  Future<void> _showContact(BuildContext context) {
    // Exact strings as requested — do not translate or rephrase.
    const lines = [
      r'developer \ Mohamed EL Sayed',
      'Phone : +201557887719',
      'جميع الحقوق محفوظة لدينا',
    ];
    return showGlassDialog<void>(
      context,
      title: t('contact'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final line in lines) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Text(
                line,
                textAlign: TextAlign.center,
                textDirection: line.startsWith('developer') ||
                        line.startsWith('Phone')
                    ? TextDirection.ltr
                    : null,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.6,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t('done')),
        ),
      ],
    );
  }

  Future<void> _test() async {
    setState(() => _testing = true);
    String msg;
    bool isError;
    try {
      final p = AiService.current();
      if (p == null) {
        msg = t('aiNotConfigured');
        isError = true;
      } else {
        final reply = await p.chat(
            [AiMsg('user', Settings.lang == 'ar' ? 'قول: تمام' : 'Say: ok')],
            system: '');
        msg = reply.isNotEmpty ? t('connectionOk') : t('connectionFail');
        isError = reply.isEmpty;
      }
    } catch (e) {
      // Show the REAL error (status code / API message / network detail)
      // under the friendly prefix — this is the diagnostic surface.
      final detail = e is AiException ? e.message : e.toString();
      msg = '${t('connectionFail')}\n$detail';
      isError = true;
    }
    if (mounted) {
      showSnack(context, msg, error: isError);
      setState(() => _testing = false);
    }
  }
}
