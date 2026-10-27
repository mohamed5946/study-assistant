import 'package:flutter/material.dart';
import 'dart:io';
import '../core/l10n.dart';
import '../core/models.dart';
import '../core/nav.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../core/motion.dart';
import '../core/pressable_3d.dart';
import 'planner_screen.dart';
import 'profile_screen.dart';
import 'scan_screen.dart';

/// Home screen per mockup: greeting row, headline, 3 stat cards,
/// AI Study Tip card, Quick Actions grid, Upcoming Sessions.
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
          builder: (_, __, ___) => ValueListenableBuilder(
            valueListenable: DB.kv.listenable(
                keys: ['profileName', 'profilePhoto']),
            builder: (_, __, ___) => _body(context),
          ),
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

    int streak = 0;
    var day = DateTime(now.year, now.month, now.day);
    while (true) {
      final ds = dayStartMs(day);
      final has = DB.pomodoro.values.any((s) =>
          s.startMs >= ds && s.startMs < ds + 86400000 && s.completed);
      if (!has) break;
      streak++;
      day = day.subtract(const Duration(days: 1));
      if (streak > 365) break;
    }

    final completedTasks =
        DB.deadlines.values.where((d) => d.done).length;

    return AuroraBackground(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
          children: [
            // top row: avatar + greeting + theme toggle
            Row(
              children: [
                _avatar(context),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          Settings.profileName.trim().isEmpty
                              ? greet
                              : '$greet، ${Settings.profileName.trim()}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 17)),
                      Text(_todayLabel(),
                          style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              fontSize: 13)),
                    ],
                  ),
                ),
                _themeToggle(),
              ],
            ),
            const SizedBox(height: 14),
            Text(t('readyToStudy'),
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 24)),
            const SizedBox(height: 14),
            // 3 stat cards
            FadeSlideIn(
              index: 1,
              child: Row(
              children: [
                Expanded(
                    child: _statCard(
                        context,
                        Icons.access_time_rounded,
                        formatMinutes(studyMin),
                        t('studyTime'),
                        AppColors.primary.withValues(alpha: 0.12),
                        AppColors.primary)),
                const SizedBox(width: 10),
                Expanded(
                    child: _statCard(
                        context,
                        Icons.task_alt_rounded,
                        '$completedTasks',
                        t('completedTasks'),
                        AppColors.secondary.withValues(alpha: 0.12),
                        AppColors.secondary)),
                const SizedBox(width: 10),
                Expanded(
                    child: _statCard(
                        context,
                        Icons.local_fire_department_rounded,
                        '$streak ${t('day_')}',
                        '${t('streak')} 🔥',
                        AppColors.warning.withValues(alpha: 0.14),
                        AppColors.warning)),
              ],
            ),
            ),
            const SizedBox(height: 14),
            // AI Study Tip card
            FadeSlideIn(
              index: 2,
              child: _tipCard(context, studyMin, streak, completedTasks,
                  todayEntries.length),
            ),
            const SizedBox(height: 16),
            SectionHeader(title: t('quickActions')),
            FadeSlideIn(
              index: 4,
              child: GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.92,
              children: [
                _qa(context, Icons.auto_awesome_rounded, t('aiChat'),
                    () => TabNav.go(2), AppColors.primary),
                _qa(context, Icons.timer_rounded, t('focusTimer'),
                    () => TabNav.go(4, more: 'pomodoro'),
                    AppColors.secondary),
                _qa(context, Icons.calendar_month_rounded, t('studyPlanner'),
                    () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const PlannerScreen())),
                    AppColors.primaryDark),
                _qa(context, Icons.document_scanner_rounded, t('scanQuestion'),
                    () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ScanScreen())),
                    AppColors.warning),
              ],
            ),
            ),
            SectionHeader(
              title: t('upcomingSessions'),
              actionLabel: t('viewAll'),
              onAction: () => TabNav.go(1),
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
              ...todayEntries.take(4).toList().asMap().entries.map(
                    (en) => FadeSlideIn(
                        index: 6 + en.key,
                        child: _classRow(context, en.value)),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _avatar(BuildContext context) {
    final path = Settings.profilePhoto;
    final file = path.isNotEmpty ? File(path) : null;
    final hasPhoto =
        file != null && file.existsSync();
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => const ProfileScreen()),
      ),
      child: Hero(
        tag: heroTag('profile', 'avatar'),
        child: Material(
          type: MaterialType.transparency,
          child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(colors: [
            AppColors.primary,
            AppColors.secondary
          ]),
          boxShadow: [
            BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 12)
          ],
          image: hasPhoto
              ? DecorationImage(
                  image: FileImage(file), fit: BoxFit.cover)
              : null,
        ),
        child: hasPhoto
            ? null
            : const Icon(Icons.person_rounded,
                color: Colors.white, size: 26),
          ),
        ),
      ),
    );
  }

  Widget _themeToggle() {
    final dark =
        Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () {
        Settings.theme = dark ? 'light' : 'dark';
      },
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: dark
              ? Colors.white.withValues(alpha: 0.10)
              : Colors.white,
          shape: BoxShape.circle,
          border: dark
              ? Border.all(
                  color: Colors.white.withValues(alpha: 0.18))
              : null,
          boxShadow: [
            BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.12),
                blurRadius: 10)
          ],
        ),
        child: Icon(
            dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            color: dark ? Colors.white : AppColors.primaryDark,
            size: 20),
      ),
    );
  }

  Widget _statCard(BuildContext context, IconData icon, String value,
      String label, Color tint, Color iconColor) {
    return Pressable3D(
      child: GlassCard(
        padding:
            const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Column(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration:
                  BoxDecoration(color: tint, shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(height: 8),
            Text(value,
                style:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 11)),
          ],
        ),
      ),
    );
  }

  /// "Today, 14 Oct" style subtitle under the greeting.
  String _todayLabel() {
    final now = DateTime.now();
    const monthsAr = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
    ];
    const monthsEn = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final ar = Settings.lang == 'ar';
    final m = ar ? monthsAr[now.month - 1] : monthsEn[now.month - 1];
    return '${t('today')}، ${now.day} $m';
  }

  /// Rule-based tip from real usage data (honest, no fake AI).
  String _tip(int studyMin, int streak, int completed, int classes) {
    final ar = Settings.lang == 'ar';
    final pending =
        DB.deadlines.values.where((d) => !d.done).length;
    if (pending > 0) {
      return ar
          ? 'عندك $pending مهام معلقة — ابدأ بأصعب واحدة لما تركيزك أعلى.'
          : 'You have $pending pending tasks — start with the hardest while focus is high.';
    }
    if (streak >= 3) {
      return ar
          ? 'سلسلة $streak أيام! حافظ عليها بجلسة تركيز واحدة النهاردة.'
          : '$streak-day streak! Keep it alive with one focus session today.';
    }
    if (studyMin < 30 && classes > 0) {
      return ar
          ? 'عندك $classes محاضرات النهاردة — راجع ملاحظاتك قبل كل محاضرة بعشر دقايق.'
          : 'You have $classes lectures today — review notes 10 min before each.';
    }
    return t('defaultTip');
  }

  Widget _tipCard(BuildContext context, int studyMin, int streak,
      int completed, int classes) {
    return Pressable3D(
      child: GlassCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.auto_awesome_rounded,
                  color: AppColors.secondary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t('aiStudyTip'),
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(_tip(studyMin, streak, completed, classes),
                      style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                          fontSize: 13,
                          height: 1.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _qa(BuildContext context, IconData icon, String label,
      VoidCallback onTap, Color color) {
    return Pressable3D(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 6),
            Text(label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _classRow(BuildContext context, TimetableEntry e) {
    final c = Color(DB.subjectColor(e.subjectId));
    final name = DB.subjectName(e.subjectId) ?? '—';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        onTap: () => TabNav.go(1),
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
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                          fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
