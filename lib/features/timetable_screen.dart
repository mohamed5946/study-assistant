import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../core/calendar_helper.dart';
import '../core/glass_sheet.dart';
import '../core/l10n.dart';
import '../core/logic.dart';
import '../core/models.dart';
import '../core/notify.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../core/grok_glass.dart';
import '../core/widget_service.dart';
import 'timetable_import_screen.dart';

const _dayKeys = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});
  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  int _weekday = DateTime.now().weekday; // 1=Mon..7=Sun
  final Map<int, GlobalKey> _dayCardKeys = {
    for (final w in [7, 1, 2, 3, 4, 5, 6]) w: GlobalKey(),
  };

  /// Exports the whole weekly timetable as formatted text and shares it.
  Future<void> _shareTimetable() async {
    final entries = DB.timetable.values.toList()
      ..sort((a, b) {
        if (a.weekday != b.weekday) return a.weekday.compareTo(b.weekday);
        return a.startMin.compareTo(b.startMin);
      });
    final buf = StringBuffer('${t('timetable')}\n');
    for (var wd = 1; wd <= 7; wd++) {
      final dayEntries = entries.where((e) => e.weekday == wd).toList();
      if (dayEntries.isEmpty) continue;
      buf.writeln('\n${t(_dayKeys[wd - 1])}:');
      for (final e in dayEntries) {
        final name = DB.subjectName(e.subjectId) ?? '—';
        final kind = e.kind == 0 ? t('lecture') : t('section');
        buf.writeln(
            '• $name ($kind) — ${formatClock(e.startMin)} → ${formatClock(e.endMin)}'
            '${e.place.isNotEmpty ? ' @ ${e.place}' : ''}');
      }
    }
    await Share.share(buf.toString(), subject: t('timetable'));
  }

  /// Adds one lecture/section as a weekly recurring calendar event.
  Future<void> _addEntryToCalendar(TimetableEntry e) async {
    final name = DB.subjectName(e.subjectId) ?? t('timetable');
    final now = DateTime.now();
    // Next occurrence of this weekday (1=Mon..7=Sun).
    var daysAhead = (e.weekday - now.weekday) % 7;
    final todayStart = DateTime(now.year, now.month, now.day,
        e.startMin ~/ 60, e.startMin % 60);
    if (daysAhead == 0 && todayStart.isBefore(now)) daysAhead = 7;
    final start = DateTime(now.year, now.month, now.day, e.startMin ~/ 60,
            e.startMin % 60)
        .add(Duration(days: daysAhead));
    final end = DateTime(now.year, now.month, now.day, e.endMin ~/ 60,
            e.endMin % 60)
        .add(Duration(days: daysAhead));
    final kind = e.kind == 0 ? t('lecture') : t('section');
    await CalendarHelper.addEvent(
      title: '$name ($kind)',
      start: start,
      end: end,
      description: [
        if (e.place.isNotEmpty) e.place,
        if (e.instructor.isNotEmpty) e.instructor,
      ].join(' • '),
      location: e.place,
      weekly: true,
      reminderMinutes: 15,
    );
  }

  @override
  Widget build(BuildContext context) {
    // v2.11: mockup weekly layout — one card per day, Sunday first,
    // with the real timetable data (the old single-day strip is gone,
    // but share/import/add/edit/delete/calendar/attendance all stay).
    final week = weekDaysSundayFirst(DateTime.now());
    final sunday = week.first.date;
    final saturday = week.last.date;
    final todayWd = DateTime.now().weekday;
    return Scaffold(
      appBar: AppBar(
        title: Text(t('timetable')),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            tooltip: t('shareTimetable'),
            onPressed: _shareTimetable,
          ),
          IconButton(
            icon: const Icon(Icons.auto_awesome_rounded),
            tooltip: t('importTimetable'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const TimetableImportScreen()),
            ),
          ),
        ],
      ),
      body: AuroraBackground(
        child: ValueListenableBuilder(
          valueListenable: DB.timetable.listenable(),
          builder: (_, __, ___) => ValueListenableBuilder(
            valueListenable: DB.subjects.listenable(),
            builder: (_, __, ___) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                child: Column(
                  children: [
                    _weekHeader(sunday, saturday, todayWd),
                    const SizedBox(height: 12),
                    for (final d in week)
                      _dayCard(d.weekday, d.date, todayWd == d.weekday),
                  ],
                ),
              );
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editEntry(null),
        icon: const Icon(Icons.add_rounded),
        label: Text(t('addEntry')),
      ),
    );
  }

  Widget _weekHeader(DateTime sunday, DateTime saturday, int todayWd) {
    return GlassCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.calendar_month_rounded,
                color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t('weekOf'),
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 16)),
                Text(
                    '${sunday.day}/${sunday.month} – ${saturday.day}/${saturday.month}',
                    style: TextStyle(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
              ],
            ),
          ),
          TextButton.icon(
            icon: const Icon(Icons.today_rounded, size: 18),
            label: Text(t('todayBtn')),
            onPressed: () {
              final ctx = _dayCardKeys[todayWd]?.currentContext;
              if (ctx != null) {
                Scrollable.ensureVisible(ctx,
                    duration: const Duration(milliseconds: 300));
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _dayCard(int weekday, DateTime date, bool isToday) {
    final list = DB.timetable.values
        .where((e) => e.weekday == weekday)
        .toList()
      ..sort((a, b) => a.startMin.compareTo(b.startMin));
    return Padding(
      key: _dayCardKeys[weekday],
      padding: const EdgeInsets.only(bottom: 14),
      child: GlassCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 72,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: (isToday ? AppColors.primary : AppColors.secondary)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Text(t(_dayKeys[weekday - 1]),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: isToday
                              ? AppColors.primary
                              : Theme.of(context)
                                  .colorScheme
                                  .onSurface)),
                  const SizedBox(height: 2),
                  Text('${date.day}/${date.month}',
                      style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant)),
                  if (isToday) ...[
                    const SizedBox(height: 4),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: list.isEmpty
                  ? Row(
                      children: [
                        const Icon(Icons.wb_sunny_rounded,
                            color: AppColors.warning, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t('restDay'),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                              Text(t('restDayHint'),
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant)),
                            ],
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        for (var i = 0; i < list.length; i++) ...[
                          _weekClassRow(list[i], isToday),
                          if (i != list.length - 1)
                            const Divider(height: 16),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// One class row inside a day card. Swipe right = edit, swipe left =
  /// delete (delete still gated by the Yes/No dialog); the popup menu
  /// carries the same actions for users who don't swipe, plus calendar.
  /// Only three controls sit in the row (attendance pair + menu) so
  /// nothing crowds or overlaps on a narrow phone.
  Widget _weekClassRow(TimetableEntry e, bool isToday) {
    final c = Color(DB.subjectColor(e.subjectId));
    final name = DB.subjectName(e.subjectId) ?? '—';
    return Dismissible(
      key: ValueKey(e.id),
      background: Container(
        alignment: AlignmentDirectional.centerStart,
        padding: const EdgeInsetsDirectional.only(start: 12),
        child: const Icon(Icons.edit_rounded, color: AppColors.primary),
      ),
      secondaryBackground: Container(
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsetsDirectional.only(end: 12),
        child: const Icon(Icons.delete_rounded, color: AppColors.error),
      ),
      confirmDismiss: (dir) async {
        if (dir == DismissDirection.startToEnd) {
          _editEntry(e);
          return false;
        }
        if (await confirmDelete(context)) {
          await Notify.cancel('class_${e.id}');
          await DB.timetable.delete(e.id);
          WidgetService.update();
          return true;
        }
        return false;
      },
      child: Row(
        children: [
          Container(
            width: 52,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
                color: c.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10)),
            child: Column(
              children: [
                Text(formatClock(e.startMin),
                    style: TextStyle(
                        fontWeight: FontWeight.w800, color: c, fontSize: 12)),
                Text(formatClock(e.endMin),
                    style: TextStyle(
                        color: c.withValues(alpha: 0.7), fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
                Text(
                  '${e.kind == 0 ? t('lecture') : t('section')}${e.instructor.isNotEmpty ? ' • ${e.instructor}' : ''}',
                  style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant,
                      fontSize: 12),
                ),
                if (e.place.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  RoomChip(room: e.place),
                ],
              ],
            ),
          ),
          if (isToday) ...[
            _attendanceButton(e, 1),
            _attendanceButton(e, 0),
          ],
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (v) async {
              if (v == 'edit') {
                _editEntry(e);
              } else if (v == 'calendar') {
                _addEntryToCalendar(e);
              } else if (v == 'delete') {
                if (await confirmDelete(context)) {
                  await Notify.cancel('class_${e.id}');
                  await DB.timetable.delete(e.id);
                  WidgetService.update();
                }
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                  value: 'edit', child: Text(t('editEntry'))),
              PopupMenuItem(
                  value: 'calendar', child: Text(t('addToCalendar'))),
              PopupMenuItem(
                  value: 'delete',
                  child: Text(t('delete'),
                      style: const TextStyle(color: AppColors.error))),
            ],
          ),
        ],
      ),
    );
  }

  /// Attendance toggle for one entry on one day. The selected button is
  /// filled; tapping re-marks (replacing the day's record for this entry).
  Widget _attendanceButton(TimetableEntry e, int status) {
    // Rebuilds when attendance changes so the selected state updates
    // immediately after a tap (the timetable list itself does not listen
    // to the attendance box).
    return ValueListenableBuilder(
      valueListenable: DB.attendance.listenable(),
      builder: (_, __, ___) {
        final dayMs = dayStartMs(DateTime.now());
        final existing = DB.attendance.values.where(
            (r) => r.entryId == e.id && r.dayMs == dayMs);
        final selected = existing.any((r) => r.status == status);
        final isPresent = status == 1;
        return IconButton(
          // Compact hit targets: the row now carries five icon buttons
          // (present/absent/calendar/edit/delete), so default 48dp
          // targets would crowd a narrow phone and squeeze the title.
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.all(4),
          constraints:
              const BoxConstraints(minWidth: 36, minHeight: 36),
          icon: Icon(
            isPresent ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: selected
                ? (isPresent ? AppColors.success : AppColors.error)
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          tooltip: isPresent ? t('present') : t('absent'),
          onPressed: () async {
            for (final r in existing) {
              await DB.attendance.delete(r.id);
            }
            final id = newId();
            await DB.attendance.put(
              id,
              AttendanceRecord(
                  id: id,
                  subjectId: e.subjectId,
                  entryId: e.id,
                  dayMs: dayMs,
                  status: status),
            );
          },
        );
      },
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

    final ok = await showGlassSheet<bool>(
      context,
      StatefulBuilder(
        builder: (ctx, setS) => Column(
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
                    onPressed: () {
                      final existing = DB.timetable.values
                          .where((x) => x.weekday == weekday)
                          .map((x) => (
                                start: x.startMin,
                                end: x.endMin,
                                id: x.id
                              ))
                          .toList();
                      if (endMin <= startMin) {
                        showSnack(ctx, t('endAfterStart'), error: true);
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
                ),
              ],
            ),
          ],
        ),
      ),
      title: e == null ? t('addEntry') : t('editEntry'),
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
    WidgetService.update();
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
