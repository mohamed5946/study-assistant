import 'package:flutter/material.dart';
import '../core/glass_sheet.dart';
import '../core/l10n.dart';
import '../core/logic.dart';
import '../core/models.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../core/widgets.dart';

class GpaScreen extends StatefulWidget {
  const GpaScreen({super.key});
  @override
  State<GpaScreen> createState() => _GpaScreenState();
}

class _GpaScreenState extends State<GpaScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  String _subjectId = '';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t('gpa'))),
      body: AuroraBackground(
        child: Column(
          children: [
            TabBar(
              controller: _tab,
              labelColor: AppColors.primaryDark,
              unselectedLabelColor:
                  Theme.of(context).colorScheme.onSurfaceVariant,
              indicatorColor: AppColors.primary,
              tabs: [
                Tab(text: t('gpa')),
                Tab(text: t('goalPlanner')),
              ],
            ),
            Expanded(
              child: ValueListenableBuilder(
                valueListenable: DB.subjects.listenable(),
                builder: (_, __, ___) => ValueListenableBuilder(
                  valueListenable: DB.grades.listenable(),
                  builder: (_, __, ___) {
                    final subjects = DB.subjects.values.toList();
                    if (_subjectId.isEmpty ||
                        DB.subjects.get(_subjectId) == null) {
                      _subjectId = subjects.isEmpty
                          ? ''
                          : subjects.first.id;
                    }
                    return TabBarView(
                      controller: _tab,
                      children: [
                        subjects.isEmpty
                            ? EmptyState(
                                icon: Icons.grade_rounded,
                                message: t('empty'))
                            : _body(subjects),
                        _GoalPlannerTab(subjects: subjects),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _tab.index == 0
          ? FloatingActionButton.extended(
              onPressed: () => _editGrade(null),
              icon: const Icon(Icons.add_rounded),
              label: Text(t('addGrade')),
            )
          : null,
    );
  }

  Widget _body(List<Subject> subjects) {
    final all = DB.grades.values.toList();
    final total = gpaFromPercents([
      for (final g in all)
        if (g.maxScore > 0)
          (pct: (g.score / g.maxScore * 100).clamp(0, 100), ch: g.creditHours),
    ]);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        GlassCard(
          gradient: const [Color(0xFFFF8A5C), AppColors.warning],
          child: Column(
            children: [
              Text(t('totalGpa'),
                  style: const TextStyle(color: Colors.white70)),
              Text(total.toStringAsFixed(2),
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 46)),
              const Text('4.0 scale',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SectionHeader(title: t('perSubject')),
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
        _subjectCard(),
      ],
    );
  }

  Widget _subjectCard() {
    final list = DB.grades.values
        .where((g) => g.subjectId == _subjectId)
        .toList();
    final gpa = gpaFromPercents([
      for (final g in list)
        if (g.maxScore > 0)
          (pct: (g.score / g.maxScore * 100).clamp(0, 100), ch: g.creditHours),
    ]);
    final sName = DB.subjectName(_subjectId) ?? '';
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(sName,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 17)),
              Text(gpa.toStringAsFixed(2),
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                      color: AppColors.primary)),
            ],
          ),
          const SizedBox(height: 8),
          if (list.isEmpty)
            Text(t('empty'),
                style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant))
          else
            ...list.map((g) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(g.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600)),
                      ),
                      Text(
                          '${g.score.toStringAsFixed(1)} / ${g.maxScore.toStringAsFixed(0)}',
                          style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant)),
                      IconButton(
                        icon: const Icon(Icons.edit_rounded, size: 20),
                        onPressed: () => _editGrade(g),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_rounded,
                            color: AppColors.error, size: 20),
                        onPressed: () async {
                          if (await confirmDelete(context)) {
                            await DB.grades.delete(g.id);
                          }
                        },
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }

  Future<void> _editGrade(GradeRecord? g) async {
    final nameC = TextEditingController(text: g?.name ?? '');
    final scoreC = TextEditingController(
        text: g != null ? g.score.toString() : '');
    final maxC = TextEditingController(
        text: g != null ? g.maxScore.toString() : '100');
    final chC = TextEditingController(
        text: g != null
            ? g.creditHours.toString()
            : (DB.subjects.get(_subjectId)?.creditHours.toString() ??
                '3'));
    final ok = await showGlassSheet<bool>(
      context,
      Builder(
        builder: (ctx) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
                controller: nameC,
                decoration:
                    InputDecoration(labelText: t('assessmentName'))),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                    child: TextField(
                        controller: scoreC,
                        keyboardType:
                            const TextInputType.numberWithOptions(
                                decimal: true),
                        decoration: InputDecoration(
                            labelText: t('score')))),
                const SizedBox(width: 10),
                Expanded(
                    child: TextField(
                        controller: maxC,
                        keyboardType:
                            const TextInputType.numberWithOptions(
                                decimal: true),
                        decoration: InputDecoration(
                            labelText: t('maxScore')))),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
                controller: chC,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration:
                    InputDecoration(labelText: t('creditHours'))),
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
      title: g == null ? t('addGrade') : t('edit'),
    );
    if (ok != true) return;
    final score = double.tryParse(scoreC.text.trim());
    final max = double.tryParse(maxC.text.trim());
    if (nameC.text.trim().isEmpty || score == null || max == null || max <= 0) {
      if (mounted) showSnack(context, t('invalidNumber'), error: true);
      return;
    }
    final id = g?.id ?? newId();
    await DB.grades.put(
      id,
      GradeRecord(
        id: id,
        subjectId: _subjectId,
        name: nameC.text.trim(),
        score: score,
        maxScore: max,
        creditHours: double.tryParse(chC.text.trim()) ?? 3,
      ),
    );
  }
}

/// GPA goal planner tab ("محتاج أجيب كام؟"):
/// previous cumulative GPA + completed hours + target -> required term GPA,
/// per-subject required grades, feasibility check, and reverse projection.
class _GoalPlannerTab extends StatefulWidget {
  final List<Subject> subjects;
  const _GoalPlannerTab({required this.subjects});

  @override
  State<_GoalPlannerTab> createState() => _GoalPlannerTabState();
}

class _GoalPlannerTabState extends State<_GoalPlannerTab> {
  final _prevGpaC = TextEditingController();
  final _prevCreditsC = TextEditingController();
  final _targetC = TextEditingController();
  final _expectedC = TextEditingController();
  final Set<String> _sel = {};
  double? _required; // null = not calculated / no credits
  bool _calculated = false;

  @override
  void initState() {
    super.initState();
    _sel.addAll(widget.subjects.map((s) => s.id));
  }

  @override
  void dispose() {
    _prevGpaC.dispose();
    _prevCreditsC.dispose();
    _targetC.dispose();
    _expectedC.dispose();
    super.dispose();
  }

  double get _currentCredits => widget.subjects
      .where((s) => _sel.contains(s.id))
      .fold<double>(0, (a, s) => a + s.creditHours);

  void _calc() {
    final prevGpa =
        double.tryParse(_prevGpaC.text.trim().replaceAll(',', '.'));
    final prevCredits =
        double.tryParse(_prevCreditsC.text.trim().replaceAll(',', '.'));
    final target =
        double.tryParse(_targetC.text.trim().replaceAll(',', '.'));
    if (prevGpa == null ||
        prevCredits == null ||
        target == null ||
        prevGpa < 0 ||
        prevGpa > 4 ||
        prevCredits < 0 ||
        target < 0 ||
        target > 4) {
      showSnack(context, t('invalidNumber'), error: true);
      return;
    }
    setState(() {
      _required = requiredTermGpa(
        prevGpa: prevGpa,
        prevCredits: prevCredits,
        targetGpa: target,
        currentCredits: _currentCredits,
      );
      _calculated = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.subjects.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(t('noSubjectsHint'),
              textAlign: TextAlign.center,
              style: TextStyle(
                  color:
                      Theme.of(context).colorScheme.onSurfaceVariant)),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        _inputsCard(),
        const SizedBox(height: 12),
        _subjectsCard(),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: GlassButton(
            label: t('calculate'),
            icon: Icons.calculate_rounded,
            onPressed: _calc,
          ),
        ),
        if (_calculated) ...[
          const SizedBox(height: 12),
          _resultCard(),
        ],
        const SizedBox(height: 12),
        _projectionCard(),
      ],
    );
  }

  Widget _inputsCard() {
    return GlassCard(
      child: Column(
        children: [
          TextField(
            controller: _prevGpaC,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
                labelText: '${t('prevGpa')} (0–4)'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _prevCreditsC,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: t('prevCredits')),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _targetC,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
                labelText: '${t('targetGpa')} (0–4)'),
          ),
        ],
      ),
    );
  }

  Widget _subjectsCard() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t('currentSubjects'),
              style:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 4),
          Text(t('selectSubjectsHint'),
              style: TextStyle(
                  color:
                      Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in widget.subjects)
                FilterChip(
                  label: Text(
                      '${s.name} (${s.creditHours.toStringAsFixed(s.creditHours.truncateToDouble() == s.creditHours ? 0 : 1)})'),
                  selected: _sel.contains(s.id),
                  selectedColor:
                      AppColors.primary.withValues(alpha: 0.2),
                  checkmarkColor: AppColors.primaryDark,
                  onSelected: (v) => setState(() {
                    if (v) {
                      _sel.add(s.id);
                    } else {
                      _sel.remove(s.id);
                    }
                    _calculated = false;
                  }),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _resultCard() {
    final req = _required;
    if (req == null) {
      return GlassCard(
        child: Text(t('selectSubjectsHint'),
            style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant)),
      );
    }
    final prevGpa =
        double.tryParse(_prevGpaC.text.trim().replaceAll(',', '.')) ?? 0;
    final prevCredits =
        double.tryParse(_prevCreditsC.text.trim().replaceAll(',', '.')) ??
            0;
    if (req > 4.0) {
      final max = maxAchievableGpa(
          prevGpa: prevGpa,
          prevCredits: prevCredits,
          currentCredits: _currentCredits);
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: AppColors.error.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_rounded,
                    color: AppColors.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(t('impossibleGoal'),
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: AppColors.error)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
                '${t('lowerTargetTo')} ${max.toStringAsFixed(2)}',
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700)),
          ],
        ),
      );
    }
    final letter = gpaLetter(req.clamp(0, 4));
    final chosen = widget.subjects
        .where((s) => _sel.contains(s.id))
        .toList();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [
          AppColors.primary,
          AppColors.primaryDark,
        ]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${t('needTermGpa')} ${t('thisTerm')}:',
              style:
                  const TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(req.toStringAsFixed(2),
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 44)),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('${letter.letter} • ${letter.ar}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16)),
              ),
            ],
          ),
          const Divider(color: Colors.white24, height: 24),
          Text(t('perSubject'),
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14)),
          const SizedBox(height: 8),
          for (final s in chosen)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(s.name,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 14)),
                  ),
                  Text(
                      '${req.toStringAsFixed(2)} • ${letter.letter} (${letter.ar})',
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _projectionCard() {
    final expected =
        double.tryParse(_expectedC.text.trim().replaceAll(',', '.'));
    final prevGpa =
        double.tryParse(_prevGpaC.text.trim().replaceAll(',', '.'));
    final prevCredits =
        double.tryParse(_prevCreditsC.text.trim().replaceAll(',', '.'));
    double? proj;
    if (expected != null &&
        prevGpa != null &&
        prevCredits != null &&
        expected >= 0 &&
        expected <= 4) {
      proj = projectedGpa(
        prevGpa: prevGpa,
        prevCredits: prevCredits,
        termGpa: expected,
        currentCredits: _currentCredits,
      );
    }
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.trending_up_rounded,
                  color: AppColors.secondary),
              const SizedBox(width: 8),
              Text(t('projection'),
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _expectedC,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
                labelText: '${t('expectedTermGpa')} (0–4)'),
            onChanged: (_) => setState(() {}),
          ),
          if (proj != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('${t('projectedResult')}: ',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700)),
                  Text(proj.toStringAsFixed(2),
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 22,
                          color: AppColors.secondary)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
