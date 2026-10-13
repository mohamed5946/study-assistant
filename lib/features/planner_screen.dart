import 'package:flutter/material.dart';
import '../core/ai.dart';
import '../core/l10n.dart';
import '../core/models.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../core/widgets.dart';

/// Study Planner: month pill + week strip + Pending/Total cards +
/// Today's Schedule timeline (dotted line) + AI Recommended Plan.
class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key});
  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  late DateTime _month;
  late DateTime _selectedDay;
  String? _aiPlan;
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _selectedDay = DateTime(now.year, now.month, now.day);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t('studyPlanner')), centerTitle: false),
      body: AuroraBackground(
        child: ValueListenableBuilder(
          valueListenable: DB.timetable.listenable(),
          builder: (_, __, ___) => ValueListenableBuilder(
            valueListenable: DB.deadlines.listenable(),
            builder: (_, __, ___) => ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
              children: [
                _monthRow(),
                const SizedBox(height: 12),
                _weekStrip(),
                const SizedBox(height: 16),
                _summaryCards(),
                const SizedBox(height: 16),
                _aiPlanCard(),
                const SizedBox(height: 16),
                _scheduleHeader(),
                const SizedBox(height: 8),
                _timeline(),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _planDialog(),
        child: const Icon(Icons.auto_awesome_rounded),
      ),
    );
  }

  Widget _monthRow() {
    final label = Settings.lang == 'ar'
        ? '${_monthNameAr(_month.month)} ${_month.year}'
        : '${_monthNameEn(_month.month)} ${_month.year}';
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _arrow(Icons.chevron_left_rounded, -1),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.w800, color: AppColors.primaryDark)),
        ),
        _arrow(Icons.chevron_right_rounded, 1),
      ],
    );
  }

  Widget _arrow(IconData icon, int dir) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => setState(() {
          _month = DateTime(_month.year, _month.month + dir);
          _selectedDay = DateTime(_month.year, _month.month, 1);
        }),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  blurRadius: 10)
            ],
          ),
          child: Icon(icon, color: AppColors.primaryDark),
        ),
      ),
    );
  }

  String _monthNameEn(int m) => const [
        '', 'January', 'February', 'March', 'April', 'May', 'June', 'July',
        'August', 'September', 'October', 'November', 'December'
      ][m];

  String _monthNameAr(int m) => const [
        '', 'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو',
        'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
      ][m];

  Widget _weekStrip() {
    // week containing selected day, Mon..Sun
    final monday = _selectedDay
        .subtract(Duration(days: _selectedDay.weekday - 1));
    const dayKeys = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var i = 0; i < 7; i++)
          Builder(builder: (_) {
            final d = monday.add(Duration(days: i));
            final sel = d.day == _selectedDay.day &&
                d.month == _selectedDay.month &&
                d.year == _selectedDay.year;
            return InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => setState(() => _selectedDay = d),
              child: Container(
                width: 42,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: sel ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: sel
                      ? [
                          BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.4),
                              blurRadius: 10)
                        ]
                      : null,
                ),
                child: Column(
                  children: [
                    Text(t(dayKeys[i]),
                        style: TextStyle(
                            fontSize: 11,
                            color: sel
                                ? Colors.white
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant)),
                    const SizedBox(height: 2),
                    Text('${d.day}',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: sel
                                ? Colors.white
                                : Theme.of(context).colorScheme.onSurface)),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _summaryCards() {
    final pending =
        DB.deadlines.values.where((d) => !d.done).length;
    final totalMin = DB.pomodoro.values
        .where((s) => s.completed)
        .fold<int>(0, (a, s) => a + s.focusMin);
    return Row(
      children: [
        Expanded(
          child: GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.pending_actions_rounded,
                      size: 18, color: AppColors.warning),
                  const SizedBox(width: 6),
                  Text(t('pendingTasks'),
                      style:
                          const TextStyle(fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 8),
                Text('$pending',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 28)),
                Text(t('pendingTasks'),
                    style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                        fontSize: 12)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GlassCard(
            gradient: const [
              AppColors.primary,
              AppColors.primaryDark,
            ],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [
                  Icon(Icons.timer_rounded, size: 18, color: Colors.white),
                  SizedBox(width: 6),
                  Text('Total',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, color: Colors.white)),
                ]),
                const SizedBox(height: 8),
                Text.rich(
                  TextSpan(
                    text: '$totalMin',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 28,
                        color: Colors.white),
                    children: const [
                      TextSpan(
                          text: ' min',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                    ],
                  ),
                ),
                Text(t('studyTime'),
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _aiPlanCard() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [
                    AppColors.primary,
                    AppColors.secondary
                  ]),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.auto_awesome_rounded,
                    color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t('aiRecommendedPlan'),
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 16)),
                    Text(t('basedOnExams'),
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
          if (_generating) ...[
            const SizedBox(height: 16),
            const StudyLoadingBar(),
          ] else if (_aiPlan != null) ...[
            const SizedBox(height: 12),
            SelectableText(_aiPlan!,
                style: const TextStyle(fontSize: 14, height: 1.7)),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: GlassButton(
              label: _aiPlan == null ? t('generatePlan') : t('viewPlan'),
              icon: Icons.auto_awesome_rounded,
              onPressed: _generating
                  ? null
                  : () {
                      if (_aiPlan == null) {
                        _planDialog();
                      } else {
                        _showFullPlan();
                      }
                    },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _planDialog() async {
    int hours = 3;
    String focus = 'revision';
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(t('studyPlanner')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${t('hoursPerDay')}: $hours'),
              Slider(
                value: hours.toDouble(),
                min: 1,
                max: 10,
                divisions: 9,
                label: '$hours',
                onChanged: (v) => setS(() => hours = v.round()),
              ),
              const SizedBox(height: 8),
              Text(t('focusType')),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  for (final f in ['deepWork', 'revision', 'examPrep'])
                    ChoiceChip(
                      label: Text(t(f)),
                      selected: focus == f,
                      selectedColor:
                          AppColors.primary.withValues(alpha: 0.2),
                      onSelected: (_) => setS(() => focus = f),
                    ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(t('cancel'))),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(t('generatePlan'))),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await _generatePlan(hours, focus);
  }

  Future<void> _generatePlan(int hours, String focus) async {
    final provider = AiService.current();
    if (provider == null) {
      if (mounted) showSnack(context, t('noApiKeyMsg'), error: true);
      return;
    }
    setState(() => _generating = true);
    try {
      final ar = Settings.lang == 'ar';
      final now = DateTime.now().millisecondsSinceEpoch;
      final exams = DB.deadlines.values
          .where((d) => !d.done && d.dueMs > now)
          .toList()
        ..sort((a, b) => a.dueMs.compareTo(b.dueMs));
      final examsInfo = exams.isEmpty
          ? (ar ? 'لا توجد امتحانات مسجلة' : 'No exams recorded')
          : exams
              .take(8)
              .map((d) {
                final due =
                    DateTime.fromMillisecondsSinceEpoch(d.dueMs);
                return '- ${d.title} (${due.day}/${due.month})';
              })
              .join('\n');
      final plan = await provider.chat(
        [AiMsg('user', 'generate')],
        system: AiService.studyPlanPrompt(
          examsInfo: examsInfo,
          hoursPerDay: hours,
          focus: t(focus),
          ar: ar,
        ),
      );
      if (!mounted) return;
      setState(() {
        _aiPlan = plan;
        _generating = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _generating = false);
      showSnack(context,
          e is AiException ? e.message : t('sendFailed'), error: true);
    }
  }

  void _showFullPlan() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        builder: (_, ctrl) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t('aiRecommendedPlan'),
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 18)),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  controller: ctrl,
                  child: SelectableText(_aiPlan ?? '',
                      style: const TextStyle(fontSize: 15, height: 1.8)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _scheduleHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(t('todaysClasses'),
            style:
                const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _addTask(),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    blurRadius: 10)
              ],
            ),
            child: const Icon(Icons.add_rounded, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Future<void> _addTask() async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(t('add')),
        content: TextField(
            controller: c,
            decoration: InputDecoration(labelText: t('title'))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(t('cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(t('save'))),
        ],
      ),
    );
    if (ok != true || c.text.trim().isEmpty) return;
    final id = newId();
    // a study task = deadline (assignment) due today, not done
    final now = DateTime.now();
    await DB.deadlines.put(
      id,
      Deadline(
        id: id,
        title: c.text.trim(),
        kind: 1,
        dueMs: DateTime(now.year, now.month, now.day, 23, 59)
            .millisecondsSinceEpoch,
      ),
    );
  }

  List<_TimelineItem> _dayItems() {
    final items = <_TimelineItem>[];
    final sel = _selectedDay;
    // classes
    final entries = DB.timetable.values
        .where((e) => e.weekday == sel.weekday)
        .toList()
      ..sort((a, b) => a.startMin.compareTo(b.startMin));
    for (final e in entries) {
      items.add(_TimelineItem(
        id: e.id,
        title: DB.subjectName(e.subjectId) ?? '—',
        subtitle:
            '${e.kind == 0 ? t('lecture') : t('section')}${e.place.isNotEmpty ? ' • ${e.place}' : ''}',
        time: '${_fmt(e.startMin)} • ${e.endMin - e.startMin} ${t('min')}',
        sortKey: e.startMin,
        done: false,
        isClass: true,
      ));
    }
    // deadlines due that day
    final dayStart = dayStartMs(sel);
    final dayEnd = dayStart + 86400000;
    for (final d in DB.deadlines.values) {
      if (d.dueMs >= dayStart && d.dueMs < dayEnd) {
        final due = DateTime.fromMillisecondsSinceEpoch(d.dueMs);
        items.add(_TimelineItem(
          id: d.id,
          title: d.title,
          subtitle: d.kind == 0 ? t('exam') : t('assignment'),
          time:
              '${due.hour.toString().padLeft(2, '0')}:${due.minute.toString().padLeft(2, '0')}',
          sortKey: due.hour * 60 + due.minute,
          done: d.done,
          isClass: false,
        ));
      }
    }
    items.sort((a, b) => a.sortKey.compareTo(b.sortKey));
    return items;
  }

  String _fmt(int min) =>
      '${(min ~/ 60).toString().padLeft(2, '0')}:${(min % 60).toString().padLeft(2, '0')}';

  Widget _timeline() {
    final items = _dayItems();
    if (items.isEmpty) {
      return GlassCard(
        child: Row(
          children: [
            const Icon(Icons.celebration_rounded, color: AppColors.warning),
            const SizedBox(width: 10),
            Text(t('noClassesToday')),
          ],
        ),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < items.length; i++)
          _timelineRow(items[i], i == items.length - 1),
      ],
    );
  }

  Widget _timelineRow(_TimelineItem it, bool last) {
    final dotColor =
        it.done ? AppColors.success : AppColors.primary;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // rail: filled dot + dotted vertical line
          SizedBox(
            width: 16,
            child: Column(
              children: [
                const SizedBox(height: 16),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: dotColor,
                    boxShadow: [
                      BoxShadow(
                          color:
                              dotColor.withValues(alpha: 0.4),
                          blurRadius: 6)
                    ],
                  ),
                ),
                if (!last)
                  Expanded(
                    child: _DottedLine(
                        color: AppColors.primary
                            .withValues(alpha: 0.35)),
                  )
                else
                  const SizedBox(height: 6),
              ],
            ),
          ),
          const SizedBox(width: 4),
          // radio circle (toggles done for tasks)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: it.isClass ? null : () => _toggleDone(it),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      it.done ? AppColors.success : Colors.white,
                  border: Border.all(
                      color: it.done
                          ? AppColors.success
                          : AppColors.lightMuted,
                      width: 2),
                ),
                child: it.done
                    ? const Icon(Icons.check_rounded,
                        size: 15, color: Colors.white)
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 4 : 16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: it.isClass ? null : () => _toggleDone(it),
                child: GlassCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(it.title,
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              decoration: it.done
                                  ? TextDecoration.lineThrough
                                  : null)),
                      Text(it.subtitle,
                          style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              fontSize: 12)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.access_time_rounded,
                              size: 14,
                              color: AppColors.lightMuted),
                          const SizedBox(width: 4),
                          Text(it.time,
                              style: const TextStyle(
                                  color: AppColors.lightMuted,
                                  fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleDone(_TimelineItem it) async {
    final d = DB.deadlines.get(it.id);
    if (d != null) {
      d.done = !d.done;
      await DB.deadlines.put(d.id, d);
    }
  }
}

/// Vertical dotted line for the planner timeline.
class _DottedLine extends StatelessWidget {
  final Color color;
  const _DottedLine({required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DottedPainter(color),
      child: const SizedBox(width: 2, height: double.infinity),
    );
  }
}

class _DottedPainter extends CustomPainter {
  final Color color;
  _DottedPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    const step = 9.0;
    final cx = size.width / 2;
    for (var y = 2.0; y < size.height - 2; y += step) {
      canvas.drawLine(Offset(cx, y), Offset(cx, y + 4.5), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) =>
      false;
}

class _TimelineItem {
  final String id, title, subtitle, time;
  final int sortKey;
  final bool done, isClass;
  _TimelineItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.sortKey,
    required this.done,
    required this.isClass,
  });
}
