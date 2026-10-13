import 'package:flutter/material.dart';
import '../core/l10n.dart';
import '../core/logic.dart';
import '../core/models.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../core/widgets.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});
  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  String _subjectId = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t('attendance'))),
      body: AuroraBackground(
        child: ValueListenableBuilder(
          valueListenable: DB.subjects.listenable(),
          builder: (_, __, ___) => ValueListenableBuilder(
            valueListenable: DB.attendance.listenable(),
            builder: (_, __, ___) {
              final subjects = DB.subjects.values.toList();
              if (subjects.isEmpty) {
                return EmptyState(
                    icon: Icons.fact_check_rounded, message: t('empty'));
              }
              if (_subjectId.isEmpty ||
                  DB.subjects.get(_subjectId) == null) {
                _subjectId = subjects.first.id;
              }
              return _subjectView(subjects);
            },
          ),
        ),
      ),
    );
  }

  Widget _subjectView(List<Subject> subjects) {
    final recs = DB.attendance.values
        .where((r) => r.subjectId == _subjectId)
        .toList()
      ..sort((a, b) => b.dayMs.compareTo(a.dayMs));
    final present = recs.where((r) => r.status == 1).length;
    final pct = attendancePct(present, recs.length);
    final threshold = Settings.attendanceThreshold;
    final low = recs.isNotEmpty && pct < threshold;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final s in subjects)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: ChoiceChip(
                    label: Text(s.name),
                    selected: _subjectId == s.id,
                    onSelected: (_) =>
                        setState(() => _subjectId = s.id),
                  ),
                ),
            ],
          ),
        ),
        GlassCard(
          gradient: const [AppColors.success, AppColors.secondary],
          child: Row(
            children: [
              SizedBox(
                width: 84,
                height: 84,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: pct / 100,
                      strokeWidth: 9,
                      color: Colors.white,
                      backgroundColor:
                          Colors.white.withValues(alpha: 0.25),
                    ),
                    Text('${pct.round()}%',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 17)),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t('attendancePct'),
                        style: const TextStyle(color: Colors.white70)),
                    Text('$present / ${recs.length}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16)),
                    if (low)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(t('belowThreshold'),
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 12)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SectionHeader(title: t('markToday')),
        Row(
          children: [
            Expanded(
              child: GlassButton(
                label: t('present'),
                icon: Icons.check_rounded,
                onPressed: () => _mark(1),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GlassButton(
                label: t('absent'),
                icon: Icons.close_rounded,
                secondary: true,
                onPressed: () => _mark(0),
              ),
            ),
          ],
        ),
        SectionHeader(title: t('history')),
        if (recs.isEmpty)
          GlassCard(child: Text(t('empty')))
        else
          ...recs.take(30).map((r) {
            final d =
                DateTime.fromMillisecondsSinceEpoch(r.dayMs);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GlassCard(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Icon(
                      r.status == 1
                          ? Icons.check_circle_rounded
                          : Icons.cancel_rounded,
                      color: r.status == 1
                          ? AppColors.success
                          : AppColors.error,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text('${d.day}/${d.month}/${d.year}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600))),
                    Text(
                        r.status == 1
                            ? t('present')
                            : t('absent'),
                        style: TextStyle(
                            color: r.status == 1
                                ? AppColors.success
                                : AppColors.error,
                            fontWeight: FontWeight.w700)),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded,
                          color: AppColors.error, size: 20),
                      onPressed: () async {
                        if (await confirmDelete(context)) {
                          await DB.attendance.delete(r.id);
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Future<void> _mark(int status) async {
    final dayMs = dayStartMs(DateTime.now());
    final existing = DB.attendance.values
        .where((r) => r.subjectId == _subjectId && r.dayMs == dayMs);
    for (final r in existing) {
      await DB.attendance.delete(r.id);
    }
    final id = newId();
    await DB.attendance.put(
      id,
      AttendanceRecord(
          id: id,
          subjectId: _subjectId,
          dayMs: dayMs,
          status: status),
    );
    if (mounted) showSnack(context, '✅');
  }
}
