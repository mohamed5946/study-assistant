import 'package:flutter/material.dart';
import '../core/glass_sheet.dart';
import '../core/l10n.dart';
import '../core/models.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../core/widget_service.dart';
import '../core/widgets.dart';
import 'subject_detail_screen.dart';

/// Next upcoming class for a subject, or null.
TimetableEntry? nextEntryFor(String subjectId) {
  final now = DateTime.now();
  final nowMin = now.hour * 60 + now.minute;
  final entries = DB.timetable.values
      .where((e) => e.subjectId == subjectId)
      .toList();
  if (entries.isEmpty) return null;
  TimetableEntry? best;
  var bestKey = 1 << 30;
  for (final e in entries) {
    // days ahead 0..6
    var ahead = (e.weekday - now.weekday) % 7;
    if (ahead < 0) ahead += 7;
    if (ahead == 0 && e.startMin <= nowMin) ahead = 7;
    final key = ahead * 1440 + e.startMin;
    if (key < bestKey) {
      bestKey = key;
      best = e;
    }
  }
  return best;
}

String dayNameL(int weekday) {
  const keys = ['', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
  return (weekday >= 1 && weekday <= 7) ? t(keys[weekday]) : '';
}

/// Attendance percentage for a subject (0..100), -1 when no records.
double attendancePct(String subjectId) {
  final recs = DB.attendance.values
      .where((r) => r.subjectId == subjectId)
      .toList();
  if (recs.isEmpty) return -1;
  final present = recs.where((r) => r.status == 1).length;
  return present / recs.length * 100;
}

/// 3D Liquid Glass subject card: layered translucent gradients, bright
/// top-edge highlight, soft colored drop shadow, press-scale animation.
class _SubjectCard extends StatefulWidget {
  final Subject s;
  final VoidCallback onTap, onEdit, onDelete;
  const _SubjectCard(
      {required this.s,
      required this.onTap,
      required this.onEdit,
      required this.onDelete});

  @override
  State<_SubjectCard> createState() => _SubjectCardState();
}

class _SubjectCardState extends State<_SubjectCard> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final accent = Color(s.colorValue);
    final next = nextEntryFor(s.id);
    final att = attendancePct(s.id);
    final pending = DB.deadlines.values
        .where((d) => d.subjectId == s.id && !d.done)
        .length;
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.97),
      onTapUp: (_) => setState(() => _scale = 1.0),
      onTapCancel: () => setState(() => _scale = 1.0),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.surface,
                accent.withValues(alpha: 0.10),
                accent.withValues(alpha: 0.18),
              ],
              stops: const [0.0, 0.6, 1.0],
            ),
            border: Border.all(
                color: Colors.white.withValues(
                    alpha: Theme.of(context).brightness == Brightness.dark
                        ? 0.16
                        : 0.8),
                width: 1.5),
            boxShadow: [
              BoxShadow(
                  color: accent.withValues(alpha: 0.30),
                  blurRadius: 22,
                  offset: const Offset(0, 12)),
              BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2)),
            ],
          ),
          child: Stack(
            children: [
              // bright top-edge highlight
              Positioned(
                top: 0,
                left: 24,
                right: 24,
                child: Container(
                  height: 2.5,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    gradient: LinearGradient(colors: [
                      Colors.transparent,
                      Colors.white.withValues(
                          alpha: Theme.of(context).brightness ==
                                  Brightness.dark
                              ? 0.5
                              : 0.95),
                      Colors.transparent,
                    ]),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                              accent,
                              accent.withValues(alpha: 0.7),
                            ]),
                            borderRadius: BorderRadius.circular(17),
                            boxShadow: [
                              BoxShadow(
                                  color:
                                      accent.withValues(alpha: 0.45),
                                  blurRadius: 12,
                                  offset: const Offset(0, 5)),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              s.name.isNotEmpty
                                  ? s.name.characters.first
                                  : '?',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 22),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(s.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 17)),
                              if (s.code.isNotEmpty)
                                Text(s.code,
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                        fontSize: 12)),
                            ],
                          ),
                        ),
                        _iconBtn(
                            Icons.edit_rounded,
                            widget.onEdit,
                            Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant),
                        _iconBtn(Icons.delete_rounded,
                            widget.onDelete, AppColors.error),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // next lecture
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.schedule_rounded,
                              size: 16, color: accent),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              next == null
                                  ? t('noLecturesScheduled')
                                  : '${t('nextLecture')}: ${dayNameL(next.weekday)} ${formatClock(next.startMin)}',
                              style: TextStyle(
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? AppColors.pink
                                      : AppColors.primaryDark,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    // stats
                    Row(
                      children: [
                        _stat(
                            context,
                            Icons.fact_check_rounded,
                            att < 0
                                ? '—'
                                : '${att.toStringAsFixed(0)}%',
                            t('attendance')),
                        _stat(
                            context,
                            Icons.pending_actions_rounded,
                            '$pending',
                            t('pendingTasks')),
                        _stat(
                            context,
                            Icons.star_rounded,
                            s.creditHours.toStringAsFixed(
                                s.creditHours.truncateToDouble() ==
                                        s.creditHours
                                    ? 0
                                    : 1),
                            t('creditHours')),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap, Color color) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, size: 20, color: color),
      ),
    );
  }

  Widget _stat(
      BuildContext context, IconData icon, String value, String label) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon,
              size: 16,
              color:
                  Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 5),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 14)),
                Text(label,
                    style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                        fontSize: 10),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SubjectsScreen extends StatelessWidget {
  const SubjectsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t('subjects'))),
      body: AuroraBackground(
        child: ValueListenableBuilder(
          valueListenable: DB.subjects.listenable(),
          builder: (_, __, ___) => ValueListenableBuilder(
            valueListenable: DB.timetable.listenable(),
            builder: (_, __, ___) => ValueListenableBuilder(
              valueListenable: DB.deadlines.listenable(),
              builder: (_, __, ___) => ValueListenableBuilder(
                valueListenable: DB.attendance.listenable(),
                builder: (_, __, ___) {
                  final list = DB.subjects.values.toList();
                  if (list.isEmpty) {
                    return EmptyState(
                      icon: Icons.book_rounded,
                      message: t('empty'),
                      actionLabel: t('addSubject'),
                      onAction: () => _edit(context, null),
                    );
                  }
                  return _list(context, list);
                },
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, null),
        icon: const Icon(Icons.add_rounded),
        label: Text(t('addSubject')),
      ),
    );
  }

  Widget _list(BuildContext context, List<Subject> list) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: list.length,
      itemBuilder: (_, i) {
        final s = list[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: _SubjectCard(
            s: s,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => SubjectDetailScreen(subject: s)),
            ),
            onEdit: () => _edit(context, s),
            onDelete: () async {
              if (await confirmDelete(context)) {
                await DB.deleteSubjectCascade(s.id);
                await WidgetService.update();
              }
            },
          ),
        );
      },
    );
  }

  Future<void> _edit(BuildContext context, Subject? s) async {
    final nameC = TextEditingController(text: s?.name ?? '');
    final codeC = TextEditingController(text: s?.code ?? '');
    final chC = TextEditingController(
        text: s != null ? s.creditHours.toString() : '3');
    int color = s?.colorValue ?? AppColors.subjectPalette.first;
    final ok = await showGlassSheet<bool>(
      context,
      StatefulBuilder(
        builder: (ctx, setS) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
                controller: nameC,
                decoration:
                    InputDecoration(labelText: t('subjectName'))),
            if (s == null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(t('csPresets'),
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(ctx).brightness == Brightness.dark
                            ? AppColors.pink
                            : AppColors.primaryDark)),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final k in [
                    'csProg', 'csDS', 'csAlgo', 'csDB',
                    'csOS', 'csNet', 'csSE'
                  ])
                    ActionChip(
                      label: Text(t(k),
                          style: const TextStyle(fontSize: 12)),
                      onPressed: () =>
                          setS(() => nameC.text = t(k)),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            TextField(
                controller: codeC,
                decoration: InputDecoration(labelText: t('subjectCode'))),
            const SizedBox(height: 10),
            TextField(
              controller: chC,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration:
                  InputDecoration(labelText: t('creditHours')),
            ),
            const SizedBox(height: 12),
            Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(t('color'))),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final c in AppColors.subjectPalette)
                  GestureDetector(
                    onTap: () => setS(() => color = c),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Color(c),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: color == c
                              ? Theme.of(ctx).colorScheme.onSurface
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(t('cancel'))),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(t('save'))),
                ),
              ],
            ),
          ],
        ),
      ),
      title: s == null ? t('addSubject') : t('editSubject'),
    );
    if (ok != true) return;
    if (nameC.text.trim().isEmpty) {
      if (context.mounted) {
        showSnack(context, t('fillAllFields'), error: true);
      }
      return;
    }
    final chRaw = double.tryParse(chC.text.trim()) ?? 3.0;
    final ch = chRaw > 0 ? chRaw : 3.0;
    if (s == null) {
      final id = newId();
      await DB.subjects.put(
        id,
        Subject(
            id: id, name: nameC.text.trim(), code: codeC.text.trim(),
            colorValue: color, creditHours: ch),
      );
    } else {
      s.name = nameC.text.trim();
      s.code = codeC.text.trim();
      s.colorValue = color;
      s.creditHours = ch;
      await DB.subjects.put(s.id, s);
    }
    await WidgetService.update();
  }
}
