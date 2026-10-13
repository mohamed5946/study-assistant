import 'package:flutter/material.dart';
import '../core/glass_sheet.dart';
import '../core/l10n.dart';
import '../core/logic.dart';
import '../core/models.dart';
import '../core/notify.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../core/widgets.dart';

class DeadlinesScreen extends StatelessWidget {
  const DeadlinesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t('deadlines'))),
      body: AuroraBackground(
        child: ValueListenableBuilder(
          valueListenable: DB.deadlines.listenable(),
          builder: (_, __, ___) => ValueListenableBuilder(
            valueListenable: DB.subjects.listenable(),
            builder: (_, __, ___) {
              final list = DB.deadlines.values.toList()
                ..sort((a, b) {
                  if (a.done != b.done) return a.done ? 1 : -1;
                  return a.dueMs.compareTo(b.dueMs);
                });
              if (list.isEmpty) {
                return EmptyState(
                  icon: Icons.event_rounded,
                  message: t('empty'),
                  actionLabel: t('addDeadline'),
                  onAction: () => _edit(context, null),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                itemCount: list.length,
                itemBuilder: (_, i) => _row(context, list[i]),
              );
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, null),
        icon: const Icon(Icons.add_rounded),
        label: Text(t('addDeadline')),
      ),
    );
  }

  Widget _row(BuildContext context, Deadline d) {
    final now = DateTime.now();
    final due = DateTime.fromMillisecondsSinceEpoch(d.dueMs);
    final overdue = due.isBefore(now) && !d.done;
    final sName = DB.subjectName(d.subjectId);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        child: Row(
          children: [
            Checkbox(
              value: d.done,
              onChanged: (v) async {
                d.done = v ?? false;
                await DB.deadlines.put(d.id, d);
                if (d.done) await Notify.cancel('deadline_${d.id}');
              },
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    d.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      decoration:
                          d.done ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  Text(
                    '${d.kind == 0 ? t('exam') : t('assignment')}${sName != null ? ' • $sName' : ''} • ${due.day}/${due.month} ${formatClock(due.hour * 60 + due.minute)}',
                    style: TextStyle(
                        color:
                            Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12),
                  ),
                  Text(
                    countdownParts(d.dueMs, now.millisecondsSinceEpoch, t),
                    style: TextStyle(
                      color: overdue
                          ? AppColors.error
                          : AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
                icon: const Icon(Icons.edit_rounded),
                onPressed: () => _edit(context, d)),
            IconButton(
              icon:
                  const Icon(Icons.delete_rounded, color: AppColors.error),
              onPressed: () async {
                if (await confirmDelete(context)) {
                  await Notify.cancel('deadline_${d.id}');
                  await DB.deadlines.delete(d.id);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context, Deadline? d) async {
    final subjects = DB.subjects.values.toList();
    final titleC = TextEditingController(text: d?.title ?? '');
    final notesC = TextEditingController(text: d?.notes ?? '');
    int kind = d?.kind ?? 0;
    String subjectId = d?.subjectId ?? '';
    DateTime due = d != null
        ? DateTime.fromMillisecondsSinceEpoch(d.dueMs)
        : DateTime.now().add(const Duration(days: 7));
    int reminder = d?.reminderMin ?? 60;

    final ok = await showGlassSheet<bool>(
      context,
      StatefulBuilder(
        builder: (ctx, setS) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
                controller: titleC,
                decoration: InputDecoration(labelText: t('title'))),
            const SizedBox(height: 10),
            SegmentedButton<int>(
              segments: [
                ButtonSegment(value: 0, label: Text(t('exam'))),
                ButtonSegment(value: 1, label: Text(t('assignment'))),
              ],
              selected: {kind},
              onSelectionChanged: (s) => setS(() => kind = s.first),
            ),
            const SizedBox(height: 10),
            LabeledDropdown<String>(
              value: subjectId.isEmpty ? null : subjectId,
              items: [
                DropdownMenuItem(value: '', child: Text('—')),
                for (final s in subjects)
                  DropdownMenuItem(value: s.id, child: Text(s.name)),
              ],
              onChanged: (v) => setS(() => subjectId = v ?? ''),
              label: t('subject'),
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: ctx,
                  initialDate: due,
                  firstDate: DateTime.now()
                      .subtract(const Duration(days: 1)),
                  lastDate:
                      DateTime.now().add(const Duration(days: 365 * 2)),
                );
                if (picked == null) return;
                if (!ctx.mounted) return;
                final tp = await showTimePicker(
                  context: ctx,
                  initialTime: TimeOfDay.fromDateTime(due),
                );
                if (tp == null) return;
                setS(() => due = DateTime(picked.year, picked.month,
                    picked.day, tp.hour, tp.minute));
              },
              child: InputDecorator(
                decoration: InputDecoration(labelText: t('date')),
                child: Text(
                    '${due.day}/${due.month}/${due.year} ${formatClock(due.hour * 60 + due.minute)}'),
              ),
            ),
            const SizedBox(height: 10),
            LabeledDropdown<int>(
              value: reminder,
              items: const [
                DropdownMenuItem(value: -1, child: Text('—')),
                DropdownMenuItem(value: 0, child: Text('0')),
                DropdownMenuItem(value: 30, child: Text('30')),
                DropdownMenuItem(value: 60, child: Text('60')),
                DropdownMenuItem(value: 1440, child: Text('1440')),
              ],
              onChanged: (v) => setS(() => reminder = v!),
              label: '${t('reminder')} (${t('minutes')})',
            ),
            const SizedBox(height: 10),
            TextField(
              controller: notesC,
              maxLines: 2,
              decoration: InputDecoration(labelText: t('notes')),
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
      title: d == null ? t('addDeadline') : t('editDeadline'),
    );
    if (ok != true) return;
    if (titleC.text.trim().isEmpty) {
      if (context.mounted) {
        showSnack(context, t('fillAllFields'), error: true);
      }
      return;
    }
    final id = d?.id ?? newId();
    final nd = Deadline(
      id: id,
      subjectId: subjectId,
      title: titleC.text.trim(),
      kind: kind,
      dueMs: due.millisecondsSinceEpoch,
      notes: notesC.text.trim(),
      done: d?.done ?? false,
      reminderMin: reminder,
    );
    await DB.deadlines.put(id, nd);
    await Notify.cancel('deadline_$id');
    if (reminder >= 0 && !nd.done) {
      await Notify.scheduleOnce(
        key: 'deadline_$id',
        title: t('deadlineReminderTitle'),
        body: nd.title,
        at: due.subtract(Duration(minutes: reminder)),
      );
    }
  }
}
