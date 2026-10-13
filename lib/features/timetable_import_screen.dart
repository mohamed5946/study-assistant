import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../core/ai.dart';
import '../core/l10n.dart';
import '../core/models.dart';
import '../core/schedule_optimizer.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../core/widget_service.dart';
import '../core/widgets.dart';

/// Smart timetable import: upload university timetable -> AI extracts
/// sessions -> user ticks registered subjects & fixes mistakes -> optimizer
/// builds a conflict-free, day-minimized personal schedule.
class TimetableImportScreen extends StatefulWidget {
  const TimetableImportScreen({super.key});
  @override
  State<TimetableImportScreen> createState() => _TimetableImportScreenState();
}

class _TimetableImportScreenState extends State<TimetableImportScreen> {
  int _step = 0; // 0 upload, 1 analyzing, 2 review, 3 result
  List<ImportedSession> _sessions = [];
  final Set<String> _selected = {}; // registered subjects
  final Map<String, String> _groupPick = {}; // subject -> group label or 'auto'
  String? _error;
  OptimizeResult? _result;
  List<(String, String)> _clashes = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t('importTimetable'))),
      body: AuroraBackground(
        child: switch (_step) {
          0 => _uploadStep(),
          1 => _analyzingStep(),
          2 => _reviewStep(),
          _ => _resultStep(),
        },
      ),
    );
  }

  Widget _uploadStep() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.secondary]),
                boxShadow: [
                  BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 24)
                ],
              ),
              child: const Icon(Icons.auto_awesome_rounded,
                  color: Colors.white, size: 44),
            ),
            const SizedBox(height: 20),
            Text(t('importTimetable'),
                style:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 22)),
            const SizedBox(height: 8),
            Text(t('importTimetableDesc'),
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 24),
            GlassButton(
              label: 'PDF',
              icon: Icons.picture_as_pdf_rounded,
              onPressed: () => _pickFile(),
            ),
            const SizedBox(height: 12),
            GlassButton(
              label: t('pickGallery'),
              icon: Icons.image_rounded,
              secondary: true,
              onPressed: () => _pickImage(ImageSource.gallery),
            ),
            const SizedBox(height: 12),
            GlassButton(
              label: t('takePhoto'),
              icon: Icons.camera_alt_rounded,
              secondary: true,
              onPressed: () => _pickImage(ImageSource.camera),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.error)),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pickFile() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (res == null || res.files.single.path == null) return;
    final bytes = await File(res.files.single.path!).readAsBytes();
    _analyze(bytes: bytes, isPdf: true);
  }

  Future<void> _pickImage(ImageSource src) async {
    final x = await ImagePicker().pickImage(source: src, maxWidth: 1600);
    if (x == null) return;
    final bytes = await File(x.path).readAsBytes();
    String mime = 'image/jpeg';
    if (x.path.toLowerCase().endsWith('.png')) mime = 'image/png';
    if (x.path.toLowerCase().endsWith('.webp')) mime = 'image/webp';
    _analyze(bytes: bytes, isPdf: false, mime: mime);
  }

  Future<void> _analyze(
      {required List<int> bytes, required bool isPdf, String mime = ''}) async {
    final provider = AiService.current();
    if (provider == null) {
      setState(() => _error = t('noApiKeyMsg'));
      return;
    }
    if (provider is! GeminiProvider) {
      setState(() => _error = t('pdfNeedsGemini'));
      return;
    }
    setState(() {
      _step = 1;
      _error = null;
    });
    try {
      final ar = Settings.lang == 'ar';
      final out = isPdf
          ? await provider.analyzePdf(
              pdfBytes: bytes,
              fileName: 'timetable.pdf',
              prompt: AiService.extractTimetablePrompt(ar: ar))
          : await provider.analyzeImage(
              bytes: bytes,
              mimeType: mime,
              prompt: AiService.extractTimetablePrompt(ar: ar));
      final list = _parseSessions(out);
      if (!mounted) return;
      if (list.isEmpty) {
        setState(() {
          _step = 0;
          _error = t('noQuestionsFound');
        });
        return;
      }
      final subjects = list.map((s) => s.subject).toSet();
      setState(() {
        _sessions = list;
        _selected.addAll(subjects);
        _groupPick.clear();
        for (final s in subjects) {
          _groupPick[s] = 'auto';
        }
        _step = 2;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _step = 0;
        _error = e is AiException ? e.message : t('sendFailed');
      });
    }
  }

  List<ImportedSession> _parseSessions(String out) {
    try {
      final start = out.indexOf('[');
      final end = out.lastIndexOf(']');
      if (start < 0 || end <= start) return [];
      final list = jsonDecode(out.substring(start, end + 1)) as List;
      return list
          .map((e) => ImportedSession.fromJson(e as Map<String, dynamic>))
          .where((s) => s.valid)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Widget _analyzingStep() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const StudyLoadingBar(),
            const SizedBox(height: 20),
            Text(t('analyzingTimetable'),
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Widget _reviewStep() {
    final bySubject = <String, List<ImportedSession>>{};
    for (final s in _sessions) {
      bySubject.putIfAbsent(s.subject, () => []).add(s);
    }
    final subjects = bySubject.keys.toList()..sort();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t('selectRegistered'),
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 4),
              Text(t('correctHint'),
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12)),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            itemCount: subjects.length,
            itemBuilder: (_, i) {
              final subj = subjects[i];
              final sess = bySubject[subj]!;
              final sel = _selected.contains(subj);
              final groups =
                  sess.map((s) => s.group).where((g) => g.isNotEmpty).toSet().toList()
                    ..sort();
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Checkbox(
                            value: sel,
                            activeColor: AppColors.primary,
                            onChanged: (v) => setState(() {
                              if (v == true) {
                                _selected.add(subj);
                              } else {
                                _selected.remove(subj);
                              }
                            }),
                          ),
                          Expanded(
                            child: Text(subj,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800, fontSize: 16)),
                          ),
                          Text('${sess.length}',
                              style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant)),
                        ],
                      ),
                      if (sel && groups.length > 1) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text('${t('pickGroup')}: ',
                                style: const TextStyle(fontSize: 13)),
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    _groupChip(subj, 'auto', t('autoOptimize')),
                                    for (final g in groups)
                                      _groupChip(subj, g, '${t('group')} $g'),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (sel) ...[
                        const SizedBox(height: 6),
                        for (final s in sess) _sessionRow(s),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: SizedBox(
            width: double.infinity,
            child: GlassButton(
              label: t('buildSchedule'),
              icon: Icons.auto_awesome_rounded,
              onPressed: _selected.isEmpty ? null : _build,
            ),
          ),
        ),
      ],
    );
  }

  Widget _groupChip(String subj, String value, String label) {
    final sel = _groupPick[subj] == value;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 6),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: sel,
        selectedColor: AppColors.primary.withValues(alpha: 0.2),
        onSelected: (_) => setState(() => _groupPick[subj] = value),
      ),
    );
  }

  Widget _sessionRow(ImportedSession s) {
    return InkWell(
      onTap: () => _editSession(s),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                  s.kind == 'section'
                      ? Icons.science_rounded
                      : Icons.school_rounded,
                  color: AppColors.primary,
                  size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      '${_dayName(s.weekday)} • ${_fmt(s.startMin)} - ${_fmt(s.endMin)}${s.group.isNotEmpty ? ' • ${t('group')} ${s.group}' : ''}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13)),
                  if (s.place.isNotEmpty || s.instructor.isNotEmpty)
                    Text(
                        [s.place, s.instructor]
                            .where((x) => x.isNotEmpty)
                            .join(' • '),
                        style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                            fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.edit_rounded,
                size: 16, color: AppColors.lightMuted),
          ],
        ),
      ),
    );
  }

  String _dayName(int w) {
    const keys = ['', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
    return (w >= 1 && w <= 7) ? t(keys[w]) : '';
  }

  String _fmt(int min) =>
      '${(min ~/ 60).toString().padLeft(2, '0')}:${(min % 60).toString().padLeft(2, '0')}';

  Future<void> _editSession(ImportedSession s) async {
    final subjC = TextEditingController(text: s.subject);
    final codeC = TextEditingController(text: s.code);
    final placeC = TextEditingController(text: s.place);
    final instC = TextEditingController(text: s.instructor);
    int day = s.weekday;
    TimeOfDay start =
        TimeOfDay(hour: s.startMin ~/ 60, minute: s.startMin % 60);
    TimeOfDay end = TimeOfDay(hour: s.endMin ~/ 60, minute: s.endMin % 60);
    String kind = s.kind;
    final groupC = TextEditingController(text: s.group);

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(t('editSession')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: subjC,
                    decoration:
                        InputDecoration(labelText: t('subjectNameCode'))),
                TextField(
                    controller: codeC,
                    decoration: const InputDecoration(labelText: 'Code')),
                const SizedBox(height: 8),
                LabeledDropdown<int>(
                  label: t('day'),
                  value: day,
                  items: [
                    for (var w = 1; w <= 7; w++)
                      DropdownMenuItem(value: w, child: Text(_dayName(w))),
                  ],
                  onChanged: (v) => setS(() => day = v ?? day),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        icon: const Icon(Icons.access_time_rounded),
                        label: Text('${t('from')} ${_fmt(start.hour * 60 + start.minute)}'),
                        onPressed: () async {
                          final p = await showTimePicker(
                              context: ctx, initialTime: start);
                          if (p != null) setS(() => start = p);
                        },
                      ),
                    ),
                    Expanded(
                      child: TextButton.icon(
                        icon: const Icon(Icons.access_time_rounded),
                        label: Text('${t('to')} ${_fmt(end.hour * 60 + end.minute)}'),
                        onPressed: () async {
                          final p = await showTimePicker(
                              context: ctx, initialTime: end);
                          if (p != null) setS(() => end = p);
                        },
                      ),
                    ),
                  ],
                ),
                LabeledDropdown<String>(
                  label: t('sessionType'),
                  value: kind,
                  items: [
                    DropdownMenuItem(
                        value: 'lecture', child: Text(t('lecture'))),
                    DropdownMenuItem(
                        value: 'section', child: Text(t('section'))),
                  ],
                  onChanged: (v) => setS(() => kind = v ?? kind),
                ),
                const SizedBox(height: 8),
                TextField(
                    controller: groupC,
                    decoration:
                        InputDecoration(labelText: '${t('group')} (${t('optional')})')),
                TextField(
                    controller: placeC,
                    decoration: InputDecoration(labelText: t('place'))),
                TextField(
                    controller: instC,
                    decoration:
                        InputDecoration(labelText: t('instructor'))),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(t('cancel'))),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(t('save'))),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final idx = _sessions.indexOf(s);
    if (idx < 0) return;
    final updated = ImportedSession(
      subject: subjC.text.trim().isEmpty ? s.subject : subjC.text.trim(),
      code: codeC.text.trim(),
      weekday: day,
      startMin: start.hour * 60 + start.minute,
      endMin: end.hour * 60 + end.minute,
      place: placeC.text.trim(),
      instructor: instC.text.trim(),
      kind: kind,
      group: groupC.text.trim(),
    );
    if (!updated.valid) {
      if (mounted) showSnack(context, t('invalidNumber'), error: true);
      return;
    }
    setState(() {
      _sessions[idx] = updated;
      final oldSubj = s.subject;
      final newSubj = updated.subject;
      if (oldSubj != newSubj) {
        if (_selected.remove(oldSubj)) _selected.add(newSubj);
        _groupPick[newSubj] = _groupPick.remove(oldSubj) ?? 'auto';
      }
    });
  }

  Future<void> _build() async {
    setState(() => _step = 1);
    await Future.delayed(const Duration(milliseconds: 300));
    final chosen =
        _sessions.where((s) => _selected.contains(s.subject)).toList();
    final built = buildOptions(chosen);

    // apply manual group picks: keep only the chosen group per subject
    final options = <String, List<List<ImportedSession>>>{};
    final labels = <String, List<String>>{};
    for (final subj in built.options.keys) {
      final pick = _groupPick[subj] ?? 'auto';
      if (pick == 'auto') {
        options[subj] = built.options[subj]!;
        labels[subj] = built.labels[subj]!;
      } else {
        final idx = built.labels[subj]!.indexOf(pick);
        if (idx >= 0) {
          options[subj] = [built.options[subj]![idx]];
          labels[subj] = [pick];
        } else {
          options[subj] = built.options[subj]!;
          labels[subj] = built.labels[subj]!;
        }
      }
    }

    final res = optimizeSchedule(options, labels);
    if (!mounted) return;
    if (res == null) {
      setState(() {
        _clashes = findClashingSubjects(chosen);
        _result = null;
        _step = 3;
      });
    } else {
      setState(() {
        _result = res;
        _clashes = [];
        _step = 3;
      });
    }
  }

  Widget _resultStep() {
    if (_result == null) {
      // conflict message naming clashing subjects
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.error.withValues(alpha: 0.12),
                ),
                child: const Icon(Icons.warning_rounded,
                    color: AppColors.error, size: 40),
              ),
              const SizedBox(height: 16),
              Text(t('conflictTitle'),
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 20)),
              const SizedBox(height: 8),
              Text(t('conflictMsg'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 12),
              for (final c in _clashes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: GlassCard(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                            child: Text(c.$1,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700))),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(Icons.compare_arrows_rounded,
                              color: AppColors.error),
                        ),
                        Flexible(
                            child: Text(c.$2,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700))),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Text(t('tryFewerSubjects'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 13)),
              const SizedBox(height: 20),
              GlassButton(
                label: t('prev'),
                icon: Icons.arrow_back_rounded,
                onPressed: () => setState(() => _step = 2),
              ),
            ],
          ),
        ),
      );
    }
    final res = _result!;
    final all = res.picks.values.expand((e) => e).toList()
      ..sort((a, b) =>
          (a.weekday * 1440 + a.startMin).compareTo(b.weekday * 1440 + b.startMin));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: GlassCard(
            gradient: const [
              AppColors.primary,
              AppColors.secondary,
            ],
            child: Row(
              children: [
                const Icon(Icons.celebration_rounded,
                    color: Colors.white, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t('scheduleBuilt'),
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 17)),
                      Text(
                          '${t('daysCompressed')} ${res.days} ${t('attendanceDays')}',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            itemCount: all.length,
            itemBuilder: (_, i) {
              final s = all[i];
              final grp = res.groups[s.subject] ?? '';
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GlassCard(
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color:
                              AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Text(_dayShort(s.weekday),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                '${s.subject}${grp.isNotEmpty ? ' (${t('group')} $grp)' : ''}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                            Text(
                                '${_fmt(s.startMin)} - ${_fmt(s.endMin)}${s.place.isNotEmpty ? ' • ${s.place}' : ''}',
                                style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                    fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Row(
            children: [
              Expanded(
                child: GlassButton(
                  label: t('prev'),
                  icon: Icons.arrow_back_rounded,
                  secondary: true,
                  onPressed: () => setState(() => _step = 2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GlassButton(
                  label: t('save'),
                  icon: Icons.check_rounded,
                  onPressed: _save,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _dayShort(int w) {
    const m = {
      1: 'Mon', 2: 'Tue', 3: 'Wed', 4: 'Thu', 5: 'Fri', 6: 'Sat', 7: 'Sun'
    };
    if (Settings.lang == 'ar') {
      const ar = {
        1: 'إث', 2: 'ثلا', 3: 'أر', 4: 'خم', 5: 'جم', 6: 'سب', 7: 'أح'
      };
      return ar[w] ?? '';
    }
    return m[w] ?? '';
  }

  Future<void> _save() async {
    final res = _result!;
    // map subject names to existing subjects, create missing ones
    final existing = {
      for (final s in DB.subjects.values) s.name.toLowerCase(): s
    };
    final palette = AppColors.subjectPalette;
    var pi = DB.subjects.length;
    var saved = 0;
    for (final e in res.picks.entries) {
      final key = e.key.toLowerCase();
      var subj = existing[key];
      if (subj == null) {
        final id = newId();
        subj = Subject(
          id: id,
          name: e.key,
          colorValue: palette[pi++ % palette.length],
        );
        await DB.subjects.put(id, subj);
        existing[key] = subj;
      }
      for (final s in e.value) {
        final id = newId();
        await DB.timetable.put(
          id,
          TimetableEntry(
            id: id,
            subjectId: subj.id,
            kind: s.kind == 'section' ? 1 : 0,
            weekday: s.weekday,
            startMin: s.startMin,
            endMin: s.endMin,
            place: s.place,
            instructor: s.instructor,
          ),
        );
        saved++;
      }
    }
    // refresh widget
    try {
      await WidgetService.update();
    } catch (_) {}
    if (!mounted) return;
    showSnack(context, '${t('scheduleBuilt')} ($saved)');
    Navigator.pop(context);
  }
}
