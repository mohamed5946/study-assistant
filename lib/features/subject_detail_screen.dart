import 'package:flutter/material.dart';
import '../core/l10n.dart';
import '../core/logic.dart';
import '../core/glass_sheet.dart';
import '../core/models.dart';
import '../core/notify.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import 'ai_chat_screen.dart';
import 'flashcards_screen.dart';
import 'library_screen.dart';
import 'notes_screen.dart';
import 'pomodoro_screen.dart';
import 'subjects_screen.dart' show nextEntryFor, dayNameL;

/// Everything about one subject: next lecture, study materials (PDFs,
/// notes, flashcards), deadlines & exams with countdowns, stats, and
/// quick actions. All wired to real data — zero dead buttons.
class SubjectDetailScreen extends StatelessWidget {
  final Subject subject;
  const SubjectDetailScreen({super.key, required this.subject});

  @override
  Widget build(BuildContext context) {
    final s = subject;
    final accent = Color(s.colorValue);
    return Scaffold(
      appBar: AppBar(title: Text(s.name)),
      body: AuroraBackground(
        child: ValueListenableBuilder(
          valueListenable: DB.timetable.listenable(),
          builder: (_, __, ___) => ValueListenableBuilder(
            valueListenable: DB.documents.listenable(),
            builder: (_, __, ___) => ValueListenableBuilder(
              valueListenable: DB.notes.listenable(),
              builder: (_, __, ___) => ValueListenableBuilder(
                valueListenable: DB.flashcards.listenable(),
                builder: (_, __, ___) => ValueListenableBuilder(
                  valueListenable: DB.deadlines.listenable(),
                  builder: (_, __, ___) => ValueListenableBuilder(
                    valueListenable: DB.pomodoro.listenable(),
                    builder: (_, __, ___) => ValueListenableBuilder(
                      valueListenable: DB.attendance.listenable(),
                      builder: (_, __, ___) =>
                          _content(context, s, accent),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(
      BuildContext context, Subject s, Color accent) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        _header(s, accent),
        const SizedBox(height: 14),
        _nextLectureCard(context, s, accent),
        const SizedBox(height: 16),
        SectionHeader(title: t('studyMaterials')),
        _studySection(context, s, accent),
        SectionHeader(title: t('deadlinesExams')),
        _deadlinesSection(context, s),
        SectionHeader(title: t('statsTitle')),
        _statsSection(context, s),
        SectionHeader(title: t('quickActions')),
        _quickActions(context, s),
      ],
    );
  }

  Widget _header(Subject s, Color accent) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent, accent.withValues(alpha: 0.65)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: accent.withValues(alpha: 0.4),
              blurRadius: 22,
              offset: const Offset(0, 10)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(19),
            ),
            child: Center(
              child: Text(
                s.name.isNotEmpty ? s.name.characters.first : '?',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 28),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 20)),
                if (s.code.isNotEmpty)
                  Text(s.code,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13)),
                Text(
                    '${s.creditHours.toStringAsFixed(s.creditHours.truncateToDouble() == s.creditHours ? 0 : 1)} ${t('creditHours')}',
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _nextLectureCard(
      BuildContext context, Subject s, Color accent) {
    final next = nextEntryFor(s.id);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: accent.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
              color: accent.withValues(alpha: 0.12),
              blurRadius: 14,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.schedule_rounded,
                color: accent, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t('nextLecture'),
                    style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                        fontSize: 12)),
                Text(
                  next == null
                      ? t('noLecturesScheduled')
                      : '${dayNameL(next.weekday)} ${formatClock(next.startMin)}'
                          '${next.place.isNotEmpty ? ' • ${next.place}' : ''}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 17),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _studySection(
      BuildContext context, Subject s, Color accent) {
    final pdfs = DB.documents.values
        .where((d) => d.subjectId == s.id)
        .toList();
    final notes = DB.notes.values
        .where((n) => n.subjectId == s.id)
        .toList();
    final cards = DB.flashcards.values
        .where((c) => c.subjectId == s.id)
        .toList();
    final now = DateTime.now().millisecondsSinceEpoch;
    final dueCards =
        cards.where((c) => c.nextReviewMs <= now).length;
    return Column(
      children: [
        _rowCard(
          context,
          icon: Icons.picture_as_pdf_rounded,
          color: AppColors.error,
          title: t('subjectPdfs'),
          subtitle: '${pdfs.length}',
          onTap: pdfs.isEmpty
              ? null
              : () => _pdfListSheet(context, s, pdfs),
        ),
        _rowCard(
          context,
          icon: Icons.note_alt_rounded,
          color: AppColors.warning,
          title: t('subjectNotes'),
          subtitle: '${notes.length}',
          onTap: notes.isEmpty
              ? null
              : () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => NotesScreen(
                            initialSubjectId: s.id)),
                  ),
        ),
        _rowCard(
          context,
          icon: Icons.style_rounded,
          color: accent,
          title: t('subjectFlashcards'),
          subtitle:
              '${cards.length} • ${t('due')}: $dueCards',
          trailing: cards.isEmpty
              ? null
              : TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => FlashcardsScreen(
                            initialSubjectId: s.id)),
                  ),
                  child: Text(t('reviewNow')),
                ),
          onTap: cards.isEmpty
              ? null
              : () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => FlashcardsScreen(
                            initialSubjectId: s.id)),
                  ),
        ),
      ],
    );
  }

  Future<void> _pdfListSheet(BuildContext context, Subject s,
      List<StudyDocument> pdfs) async {
    await showGlassSheet(
      context,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final d in pdfs)
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_rounded,
                  color: AppColors.error),
              title: Text(d.name,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => PdfViewerScreen(doc: d)),
                );
              },
            ),
        ],
      ),
      title: t('subjectPdfs'),
    );
  }

  Widget _deadlinesSection(BuildContext context, Subject s) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final items = DB.deadlines.values
        .where((d) => d.subjectId == s.id && !d.done)
        .toList()
      ..sort((a, b) => a.dueMs.compareTo(b.dueMs));
    if (items.isEmpty) {
      return GlassCard(
        child: Text(t('empty'),
            style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant)),
      );
    }
    return Column(
      children: [
        for (final d in items.take(5))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GlassCard(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: (d.kind == 0
                              ? AppColors.error
                              : AppColors.warning)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                        d.kind == 0
                            ? Icons.quiz_rounded
                            : Icons.assignment_rounded,
                        color: d.kind == 0
                            ? AppColors.error
                            : AppColors.warning),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(d.title,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700)),
                        Text(
                          countdownParts(d.dueMs, now, t),
                          style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.check_circle_outline_rounded,
                        color: AppColors.success),
                    tooltip: t('done'),
                    onPressed: () async {
                      d.done = true;
                      await DB.deadlines.put(d.id, d);
                      await Notify.cancel('deadline_${d.id}');
                    },
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _statsSection(BuildContext context, Subject s) {
    final now = DateTime.now();
    final weekAgo =
        now.subtract(const Duration(days: 7)).millisecondsSinceEpoch;
    final studyMin = DB.pomodoro.values
        .where((p) =>
            p.subjectId == s.id &&
            p.startMs >= weekAgo &&
            p.completed)
        .fold<int>(0, (a, p) => a + p.focusMin);
    final recs = DB.attendance.values
        .where((r) => r.subjectId == s.id)
        .toList();
    final attPct = recs.isEmpty
        ? -1.0
        : recs.where((r) => r.status == 1).length /
            recs.length *
            100;
    final examIds = DB.exams.values
        .where((e) => e.subjectId == s.id)
        .map((e) => e.id)
        .toSet();
    final attempts = DB.attempts.values
        .where((a) =>
            examIds.contains(a.examId) && a.maxScore > 0)
        .toList();
    final quizAvg = attempts.isEmpty
        ? -1.0
        : attempts
                .map((a) => a.score / a.maxScore * 100)
                .reduce((a, b) => a + b) /
            attempts.length;
    return Row(
      children: [
        Expanded(
            child: _statTile(context, Icons.timer_rounded,
                formatMinutes(studyMin), t('studyTimeWeek'),
                AppColors.primary)),
        const SizedBox(width: 10),
        Expanded(
            child: _statTile(
                context,
                Icons.fact_check_rounded,
                attPct < 0
                    ? '—'
                    : '${attPct.toStringAsFixed(0)}%',
                t('attendanceRate'),
                AppColors.secondary)),
        const SizedBox(width: 10),
        Expanded(
            child: _statTile(
                context,
                Icons.quiz_rounded,
                quizAvg < 0
                    ? '—'
                    : '${quizAvg.toStringAsFixed(0)}%',
                t('quizAvg'),
                AppColors.warning)),
      ],
    );
  }

  Widget _statTile(BuildContext context, IconData icon,
      String value, String label, Color color) {
    return GlassCard(
      radius: 18,
      padding:
          const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 19),
          ),
          const SizedBox(height: 6),
          Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.w800)),
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant,
                  fontSize: 10),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _quickActions(BuildContext context, Subject s) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.9,
      children: [
        _qa(context, Icons.timer_rounded, t('studyAction'),
            AppColors.primary, () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => PomodoroScreen(
                    initialSubjectId: s.id)),
          );
        }),
        _qa(context, Icons.auto_awesome_rounded,
            t('askAboutSubject'), AppColors.secondary, () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => AiChatScreen(
                    initialPrompt:
                        '${t('askAboutSubject')} (${s.name}): ')),
          );
        }),
        _qa(context, Icons.upload_file_rounded, t('uploadPdf'),
            AppColors.warning, () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    LibraryScreen(initialSubjectId: s.id)),
          );
        }),
        _qa(context, Icons.note_add_rounded, t('addNote'),
            AppColors.primaryDark, () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    NotesScreen(initialSubjectId: s.id)),
          );
        }),
      ],
    );
  }

  Widget _qa(BuildContext context, IconData icon, String label,
      Color color, VoidCallback onTap) {
    return GlassCard(
      radius: 18,
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
    );
  }

  Widget _rowCard(BuildContext context,
      {required IconData icon,
      required Color color,
      required String title,
      required String subtitle,
      Widget? trailing,
      VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        radius: 18,
        onTap: onTap,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15)),
                  Text(subtitle,
                      style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                          fontSize: 12)),
                ],
              ),
            ),
            if (trailing != null)
              trailing
            else if (onTap != null)
              Icon(Icons.chevron_right_rounded,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
