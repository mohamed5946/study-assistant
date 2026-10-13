import 'package:flutter/material.dart';
import '../core/l10n.dart';
import '../core/logic.dart';
import '../core/models.dart';
import '../core/notify.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../core/widgets.dart';

const _dayKeys = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});
  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  int _weekday = DateTime.now().weekday; // 1=Mon..7=Sun

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t('timetable'))),
      body: AuroraBackground(
        child: Column(
          children: [
            _dayStrip(),
            Expanded(
              child: ValueListenableBuilder(
                valueListenable: DB.timetable.listenable(),
                builder: (_, __, ___) => ValueListenableBuilder(
                  valueListenable: DB.subjects.listenable(),
                  builder: (_, __, ___) {
                    final list = DB.timetable.values
                        .where((e) => e.weekday == _weekday)
                        .toList()
                      ..sort((a, b) => a.startMin.compareTo(b.startMin));
                    if (list.isEmpty) {
                      return EmptyState(
                        icon: Icons.calendar_month_rounded,
                        message: t('empty'),
                        actionLabel: t('addEntry'),
                        onAction: () => _editEntry(null),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      itemCount: list.length,
                      itemBuilder: (_, i) => _entryCard(list[i]),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editEntry(null),
        icon: const Icon(Icons.add_rounded),
        label: Text(t('addEntry')),
      ),
    );
  }

  Widget _dayStrip() {
    return SizedBox(
      height: 64,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: 7,
        itemBuilder: (_, i) {
          final wd = i + 1;
          final sel = wd == _weekday;
          return GestureDetector(
            onTap: () => setState(() => _weekday = wd),
            child: Container(
              width: 76,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: sel
                    ? const LinearGradient(
                        colors: [AppColors.primary, AppColors.violet])
                    : null,
                color: sel
                    ? null
                    : Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.5),
              ),
              child: Center(
                child: Text(
                  t(_dayKeys[i]),
                  style: TextStyle(
                    color: sel
                        ? Colors.white
                        : Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _entryCard(TimetableEntry e) {
    final c = Color(DB.subjectColor(e.subjectId));
    final name = DB.subjectName(e.subjectId) ?? '—';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        child: Row(
          children: [
            Container(
              width: 56,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  Text(formatClock(e.startMin),
                      style: TextStyle(
                          fontWeight: FontWeight.w800, color: c, fontSize: 13)),
                  Text(formatClock(e.endMin),
                      style: TextStyle(
                          color: c.withValues(alpha: 0.7), fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16)),
                  Text(
                    '${e.kind == 0 ? t('lecture') : t('section')}${e.place.isNotEmpty ? ' • ${e.place}' : ''}${e.instructor.isNotEmpty ? ' • ${e.instructor}' : ''}',
                    style: TextStyle(
                        color:
                            Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12),
                  ),
                ],
              ),
            ),
            IconButton(
                icon: const Icon(Icons.edit_rounded),
                onPressed: () => _editEntry(e)),
            IconButton(
              icon: const Icon(Icons.delete_rounded, color: AppColors.error),
              onPressed: () async {
                if (await confirmDelete(context)) {
                  await Notify.cancel('class_${e.id}');
                  await DB.timetable.delete(e.id);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editEntry(TimetableEntry? e) async {
    final subjects = DB.subjects.values.toList();
    if (subjects.isEmpty) {
      if (mounted) {
        showSnack(context, t('addSubject'), error: true);
      }
      return;
    }
    String subjectId = e?.subjectId ?? subjects.first.id;
    if (DB.subjects.get(subjectId) == null) subjectId = subjects.first.id;
    int kind = e?.kind ?? 0;
    int weekday = e?.weekday ?? _weekday;
    int startMin = e?.startMin ?? 540;
    int endMin = e?.endMin ?? 630;
    final placeC = TextEditingController(text: e?.place ?? '');
    final instC = TextEditingController(text: e?.instructor ?? '');
    int reminder = e?.reminderMin ?? 15;
    bool overlapWarned = false;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(e == null ? t('addEntry') : t('editEntry')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LabeledDropdown<String>(
                  value: subjectId,
                  items: [
                    for (final s in subjects)
                      DropdownMenuItem(value: s.id, child: Text(s.name))
                  ],
                  onChanged: (v) => setS(() => subjectId = v!),
                  label: t('subject'),
                ),
                const SizedBox(height: 10),
                SegmentedButton<int>(
                  segments: [
                    ButtonSegment(value: 0, label: Text(t('lecture'))),
                    ButtonSegment(value: 1, label: Text(t('section'))),
                  ],
                  selected: {kind},
                  onSelectionChanged: (s) => setS(() => kind = s.first),
                ),
                const SizedBox(height: 10),
                LabeledDropdown<int>(
                  value: weekday,
                  items: [
                    for (final i in List.generate(7, (k) => k))
                      DropdownMenuItem(
                          value: i + 1, child: Text(t(_dayKeys[i])))
                  ],
                  onChanged: (v) => setS(() => weekday = v!),
                  label: t('day'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final tp = await showTimePicker(
                            context: ctx,
                            initialTime: TimeOfDay(
                                hour: startMin ~/ 60, minute: startMin % 60),
                          );
                          if (tp != null) {
                            setS(() => startMin = tp.hour * 60 + tp.minute);
                          }
                        },
                        child: InputDecorator(
                          decoration: InputDecoration(labelText: t('from')),
                          child: Text(formatClock(startMin)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final tp = await showTimePicker(
                            context: ctx,
                            initialTime: TimeOfDay(
                                hour: endMin ~/ 60, minute: endMin % 60),
                          );
                          if (tp != null) {
                            setS(() => endMin = tp.hour * 60 + tp.minute);
                          }
                        },
                        child: InputDecorator(
                          decoration: InputDecoration(labelText: t('to')),
                          child: Text(formatClock(endMin)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                    controller: placeC,
                    decoration: InputDecoration(labelText: t('place'))),
                const SizedBox(height: 10),
                TextField(
                    controller: instC,
                    decoration: InputDecoration(labelText: t('instructor'))),
                const SizedBox(height: 10),
                LabeledDropdown<int>(
                  value: reminder,
                  items: const [
                    DropdownMenuItem(value: -1, child: Text('—')),
                    DropdownMenuItem(value: 0, child: Text('0')),
                    DropdownMenuItem(value: 5, child: Text('5')),
                    DropdownMenuItem(value: 10, child: Text('10')),
                    DropdownMenuItem(value: 15, child: Text('15')),
                    DropdownMenuItem(value: 30, child: Text('30')),
                    DropdownMenuItem(value: 60, child: Text('60')),
                  ],
                  onChanged: (v) => setS(() => reminder = v!),
                  label: '${t('reminder')} (${t('minutes')})',
                ),
                if (overlapWarned)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(t('overlapWarning'),
                        style: const TextStyle(color: AppColors.warning)),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(t('cancel'))),
            FilledButton(
              onPressed: () {
                final existing = DB.timetable.values
                    .where((x) => x.weekday == weekday)
                    .map((x) => (start: x.startMin, end: x.endMin, id: x.id))
                    .toList();
                if (endMin <= startMin) {
                  showSnack(ctx, t('invalidNumber'), error: true);
                  return;
                }
                if (hasOverlap(existing, weekday, startMin, endMin,
                    excludeId: e?.id ?? '')) {
                  setS(() => overlapWarned = true);
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: Text(t('save')),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final id = e?.id ?? newId();
    final entry = TimetableEntry(
      id: id,
      subjectId: subjectId,
      kind: kind,
      weekday: weekday,
      startMin: startMin,
      endMin: endMin,
      place: placeC.text.trim(),
      instructor: instC.text.trim(),
      reminderMin: reminder,
    );
    await DB.timetable.put(id, entry);
    // (re)schedule reminder
    await Notify.cancel('class_$id');
    if (reminder >= 0) {
      final sName = DB.subjectName(subjectId) ?? '';
      await Notify.scheduleClass(
        key: 'class_$id',
        title: t('classReminderTitle'),
        body: '$sName • ${formatClock(startMin)}${placeC.text.trim().isNotEmpty ? ' • ${placeC.text.trim()}' : ''}',
        weekday: weekday,
        minutesBefore: reminder,
        classStartMin: startMin,
      );
    }
    if (mounted) setState(() => _weekday = weekday);
  }
}
