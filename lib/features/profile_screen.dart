import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../core/l10n.dart';
import '../core/logic.dart';
import '../core/models.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../core/widgets.dart';

/// Profile: photo, name, university, faculty, academic year + grade history
/// (per-term subject grades with averages). All local in Hive.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController _nameC, _uniC, _facC;
  late int _year;
  File? _photo;
  final Set<String> _expanded = {};

  @override
  void initState() {
    super.initState();
    _nameC = TextEditingController(text: Settings.profileName);
    _uniC = TextEditingController(text: Settings.university);
    _facC = TextEditingController(text: Settings.faculty);
    _year = Settings.academicYear.clamp(1, 7);
    if (Settings.profilePhoto.isNotEmpty) {
      final f = File(Settings.profilePhoto);
      if (f.existsSync()) _photo = f;
    }
  }

  @override
  void dispose() {
    _saveBasics();
    _nameC.dispose();
    _uniC.dispose();
    _facC.dispose();
    super.dispose();
  }

  void _saveBasics() {
    Settings.profileName = _nameC.text.trim();
    Settings.university = _uniC.text.trim();
    Settings.faculty = _facC.text.trim();
    Settings.academicYear = _year;
  }

  Future<void> _pickPhoto() async {
    final x = await ImagePicker()
        .pickImage(source: ImageSource.gallery, maxWidth: 800);
    if (x == null) return;
    final dir = await getApplicationDocumentsDirectory();
    final dest =
        File('${dir.path}/profile_photo_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await File(x.path).copy(dest.path);
    // remove old photo file
    if (Settings.profilePhoto.isNotEmpty) {
      try {
        await File(Settings.profilePhoto).delete();
      } catch (_) {}
    }
    Settings.profilePhoto = dest.path;
    setState(() => _photo = dest);
  }

  String _yearName(int y) {
    if (Settings.lang == 'ar') {
      const names = [
        '', 'السنة الأولى', 'السنة الثانية', 'السنة الثالثة',
        'السنة الرابعة', 'السنة الخامسة', 'السنة السادسة', 'السنة السابعة'
      ];
      return names[y];
    }
    return 'Year $y';
  }

  String _termName(int term) =>
      term == 1 ? t('term1') : t('term2');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t('profile'))),
      body: AuroraBackground(
        child: ValueListenableBuilder(
          valueListenable: DB.termGrades.listenable(),
          builder: (_, __, ___) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            children: [
              _headerCard(),
              const SizedBox(height: 16),
              _basicsCard(),
              const SizedBox(height: 16),
              _gradesSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerCard() {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(44),
            onTap: _pickPhoto,
            child: Stack(
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(colors: [
                      AppColors.primary,
                      AppColors.secondary
                    ]),
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.primary
                              .withValues(alpha: 0.3),
                          blurRadius: 16)
                    ],
                    image: _photo != null
                        ? DecorationImage(
                            image: FileImage(_photo!),
                            fit: BoxFit.cover)
                        : null,
                  ),
                  child: _photo == null
                      ? const Icon(Icons.person_rounded,
                          color: Colors.white, size: 44)
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                    child: const Icon(Icons.camera_alt_rounded,
                        size: 16, color: AppColors.primaryDark),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    _nameC.text.trim().isEmpty
                        ? t('yourName')
                        : _nameC.text.trim(),
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 19)),
                if (_uniC.text.trim().isNotEmpty)
                  Text(_uniC.text.trim(),
                      style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                          fontSize: 13)),
                if (_facC.text.trim().isNotEmpty)
                  Text(_facC.text.trim(),
                      style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                          fontSize: 13)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color:
                        AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(_yearName(_year),
                      style: const TextStyle(
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.w700,
                          fontSize: 12)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _basicsCard() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t('personalInfo'),
              style: const TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 12),
          TextField(
            controller: _nameC,
            decoration: InputDecoration(labelText: t('name')),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _uniC,
            decoration:
                InputDecoration(labelText: t('university')),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _facC,
            decoration: InputDecoration(labelText: t('faculty')),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          LabeledDropdown<int>(
            label: t('academicYear'),
            value: _year,
            items: [
              for (var y = 1; y <= 7; y++)
                DropdownMenuItem(
                    value: y, child: Text(_yearName(y))),
            ],
            onChanged: (v) => setState(() {
              _year = v ?? 1;
              _saveBasics();
            }),
          ),
        ],
      ),
    );
  }

  Widget _gradesSection() {
    final all = DB.termGrades.values.toList();
    final cum = gradeAverage(
        all.map((g) => (g.grade, g.maxGrade)).toList());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: t('gradeHistory')),
        // cumulative average card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [
              AppColors.primary,
              AppColors.primaryDark
            ]),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 8)),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.grade_rounded,
                  color: Colors.white, size: 36),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t('cumulativeAverage'),
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13)),
                    Text(
                        all.isEmpty
                            ? '—'
                            : '${cum.toStringAsFixed(1)}%',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 30)),
                  ],
                ),
              ),
              Text('${all.length} ${t('subjectsCount')}',
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (var y = 1; y <= _year; y++) ...[
          for (var tm = 1; tm <= 2; tm++) _termTile(y, tm),
        ],
      ],
    );
  }

  Widget _termTile(int year, int term) {
    final key = '${year}_$term';
    final entries = DB.termGrades.values
        .where((g) => g.year == year && g.term == term)
        .toList()
      ..sort((a, b) => a.subject.compareTo(b.subject));
    final avg =
        gradeAverage(entries.map((g) => (g.grade, g.maxGrade)).toList());
    final open = _expanded.contains(key);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => setState(() {
                if (open) {
                  _expanded.remove(key);
                } else {
                  _expanded.add(key);
                }
              }),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.secondary
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                          Icons.school_rounded,
                          color: AppColors.secondary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text('${_yearName(year)} • ${_termName(term)}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15)),
                          Text(
                              entries.isEmpty
                                  ? t('noGradesYet')
                                  : '${t('termAverage')}: ${avg.toStringAsFixed(1)}% (${entries.length})',
                              style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                  fontSize: 12)),
                        ],
                      ),
                    ),
                    Icon(
                        open
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        color: AppColors.lightMuted),
                  ],
                ),
              ),
            ),
            if (open) ...[
              const Divider(height: 1),
              for (final g in entries) _gradeRow(g),
              Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.add_rounded),
                    label: Text(t('addGrade')),
                    onPressed: () =>
                        _gradeDialog(year: year, term: term),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _gradeRow(TermGrade g) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(g.subject,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700)),
                Text('${g.grade} / ${g.maxGrade}',
                    style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                        fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _pctColor(g.pct).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('${g.pct.toStringAsFixed(1)}%',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: _pctColor(g.pct),
                    fontSize: 13)),
          ),
          IconButton(
            icon: const Icon(Icons.edit_rounded, size: 18),
            onPressed: () => _gradeDialog(existing: g),
          ),
          IconButton(
            icon: const Icon(Icons.delete_rounded,
                size: 18, color: AppColors.error),
            onPressed: () async {
              if (await confirmDelete(context)) {
                await DB.termGrades.delete(g.id);
              }
            },
          ),
        ],
      ),
    );
  }

  Color _pctColor(double pct) {
    if (pct >= 85) return AppColors.success;
    if (pct >= 60) return AppColors.primary;
    if (pct >= 50) return AppColors.warning;
    return AppColors.error;
  }

  Future<void> _gradeDialog(
      {int year = 1, int term = 1, TermGrade? existing}) async {
    final subC =
        TextEditingController(text: existing?.subject ?? '');
    final gradeC = TextEditingController(
        text: existing != null ? '${existing.grade}' : '');
    final maxC = TextEditingController(
        text: existing != null ? '${existing.maxGrade}' : '100');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text(
            existing == null ? t('addGrade') : t('editGrade')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: subC,
                decoration:
                    InputDecoration(labelText: t('subjectName'))),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                      controller: gradeC,
                      keyboardType:
                          const TextInputType.numberWithOptions(
                              decimal: true),
                      decoration: InputDecoration(
                          labelText: t('grade'))),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                      controller: maxC,
                      keyboardType:
                          const TextInputType.numberWithOptions(
                              decimal: true),
                      decoration: InputDecoration(
                          labelText: t('maxGrade'))),
                ),
              ],
            ),
          ],
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
    final grade = double.tryParse(gradeC.text.trim()) ?? -1;
    final max =
        double.tryParse(maxC.text.trim()) ?? 100;
    if (subC.text.trim().isEmpty || grade < 0 || max <= 0) {
      if (mounted) showSnack(context, t('invalidNumber'), error: true);
      return;
    }
    if (existing != null) {
      existing.subject = subC.text.trim();
      existing.grade = grade;
      existing.maxGrade = max;
      await DB.termGrades.put(existing.id, existing);
    } else {
      final id = newId();
      await DB.termGrades.put(
        id,
        TermGrade(
            id: id,
            year: year,
            term: term,
            subject: subC.text.trim(),
            grade: grade,
            maxGrade: max),
      );
    }
  }
}
