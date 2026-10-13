import 'package:flutter/material.dart';
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

class _GpaScreenState extends State<GpaScreen> {
  String _subjectId = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t('gpa'))),
      body: AuroraBackground(
        child: ValueListenableBuilder(
          valueListenable: DB.subjects.listenable(),
          builder: (_, __, ___) => ValueListenableBuilder(
            valueListenable: DB.grades.listenable(),
            builder: (_, __, ___) {
              final subjects = DB.subjects.values.toList();
              if (subjects.isEmpty) {
                return EmptyState(
                    icon: Icons.grade_rounded, message: t('empty'));
              }
              if (_subjectId.isEmpty ||
                  DB.subjects.get(_subjectId) == null) {
                _subjectId = subjects.first.id;
              }
              return _body(subjects);
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editGrade(null),
        icon: const Icon(Icons.add_rounded),
        label: Text(t('addGrade')),
      ),
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text(g == null ? t('addGrade') : t('edit')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
            ],
          ),
        ),
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
