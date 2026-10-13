import 'package:flutter/material.dart';
import '../core/l10n.dart';
import '../core/logic.dart';
import '../core/models.dart';
import '../core/nav.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../core/widgets.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: DB.timetable.listenable(),
      builder: (_, __, ___) => ValueListenableBuilder(
        valueListenable: DB.deadlines.listenable(),
        builder: (_, __, ___) => ValueListenableBuilder(
          valueListenable: DB.pomodoro.listenable(),
          builder: (_, __, ___) => _body(context),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final now = DateTime.now();
    final hour = now.hour;
    final greet = hour < 12
        ? t('goodMorning')
        : hour < 18
            ? t('goodAfternoon')
            : t('goodEvening');

    final todayEntries = DB.timetable.values
        .where((e) => e.weekday == now.weekday)
        .toList()
      ..sort((a, b) => a.startMin.compareTo(b.startMin));

    final todayStart = dayStartMs(now);
    final studyMin = DB.pomodoro.values
        .where((s) => s.startMs >= todayStart && s.completed)
        .fold<int>(0, (a, s) => a + s.focusMin);

    // streak: consecutive days with >=1 completed pomodoro
    int streak = 0;
    var day = DateTime(now.year, now.month, now.day);
    while (true) {
      final ds = dayStartMs(day);
      final has = DB.pomodoro.values
          .any((s) => s.startMs >= ds && s.startMs < ds + 86400000 && s.completed);
      if (!has) break;
      streak++;
      day = day.subtract(const Duration(days: 1));
      if (streak > 365) break;
    }

    final pendingDeadlines =
        DB.deadlines.values.where((d) => !d.done).length;

    final upcoming = DB.deadlines.values
        .where((d) => !d.done)
        .toList()
      ..sort((a, b) => a.dueMs.compareTo(b.dueMs));

    return AuroraBackground(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                        colors: [AppColors.primary, AppColors.violet]),
                  ),
                  child: const Icon(Icons.school_rounded,
                      color: Colors.white, size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(greet,
                          style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              fontSize: 13)),
                      Text(t('readyToStudy'),
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 20)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                    child: StatCard(
                        icon: Icons.timer_rounded,
                        value: formatMinutes(studyMin),
                        label: t('studyTime'),
                        gradient: const [
                      AppColors.primary,
                      AppColors.secondary
                    ])),
                const SizedBox(width: 12),
                Expanded(
                    child: StatCard(
                        icon: Icons.local_fire_department_rounded,
                        value: '$streak',
                        label: t('streak'),
                        gradient: const [
                      Color(0xFFFF8A5C),
                      AppColors.pink
                    ])),
                const SizedBox(width: 12),
                Expanded(
                    child: StatCard(
                        icon: Icons.task_alt_rounded,
                        value: '$pendingDeadlines',
                        label: t('pendingTasks'),
                        gradient: const [
                      AppColors.violet,
                      AppColors.secondary
                    ])),
              ],
            ),
            SectionHeader(title: t('quickActions')),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.85,
              children: [
                _qa(context, Icons.auto_awesome_rounded, t('aiChat'), 2,
                    const [AppColors.violet, AppColors.primary]),
                _qa(context, Icons.timer_rounded, t('focusTimer'), 4,
                    const [AppColors.primary, AppColors.secondary],
                    more: 'pomodoro'),
                _qa(context, Icons.style_rounded, t('flashcards'), 3,
                    const [AppColors.secondary, AppColors.success],
                    study: 'flashcards'),
                _qa(context, Icons.quiz_rounded, t('myExams'), 3,
                    const [AppColors.pink, AppColors.violet], study: 'exams'),
              ],
            ),
            SectionHeader(
              title: t('todaysClasses'),
              actionLabel: t('viewAll'),
              onAction: () => _goTab(context, 1),
            ),
            if (todayEntries.isEmpty)
              GlassCard(
                  child: Row(children: [
                const Icon(Icons.celebration_rounded,
                    color: AppColors.warning),
                const SizedBox(width: 10),
                Text(t('noClassesToday'))
              ]))
            else
              ...todayEntries.map((e) => _classRow(context, e)),
            SectionHeader(
              title: t('upcomingDeadlines'),
              actionLabel: t('viewAll'),
              onAction: () => _goTab(context, 4, more: 'deadlines'),
            ),
            if (upcoming.isEmpty)
              GlassCard(
                  child: Row(children: [
                const Icon(Icons.check_circle_rounded,
                    color: AppColors.success),
                const SizedBox(width: 10),
                Text(t('empty'))
              ]))
            else
              ...upcoming
                  .take(3)
                  .map((d) => _deadlineRow(context, d, now)),
          ],
        ),
      ),
    );
  }

  Widget _qa(BuildContext context, IconData icon, String label, int tab,
      List<Color> g, {String? more, String? study}) {
    return GlassCard(
      padding: const EdgeInsets.all(8),
      onTap: () => _goTab(context, tab, more: more, study: study),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: g),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 6),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  void _goTab(BuildContext context, int tab, {String? more, String? study}) {
    TabNav.go(tab, more: more, study: study);
  }

  Widget _classRow(BuildContext context, TimetableEntry e) {
    final c = Color(DB.subjectColor(e.subjectId));
    final name = DB.subjectName(e.subjectId) ?? '—';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        child: Row(
          children: [
            Container(
                width: 6,
                height: 52,
                decoration: BoxDecoration(
                    color: c, borderRadius: BorderRadius.circular(6))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                  Text(
                      '${e.kind == 0 ? t('lecture') : t('section')} • ${formatClock(e.startMin)} - ${formatClock(e.endMin)}${e.place.isNotEmpty ? ' • ${e.place}' : ''}',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _deadlineRow(BuildContext context, Deadline d, DateTime now) {
    final due = DateTime.fromMillisecondsSinceEpoch(d.dueMs);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        child: Row(
          children: [
            Icon(
                d.kind == 0 ? Icons.quiz_rounded : Icons.assignment_rounded,
                color: due.isBefore(now) ? AppColors.error : AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d.title,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(
                    countdownParts(d.dueMs, now.millisecondsSinceEpoch, t),
                    style: TextStyle(
                        color: due.isBefore(now)
                            ? AppColors.error
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

}
