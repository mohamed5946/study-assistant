import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../core/l10n.dart';
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
          valueListenable: DB.termGpas.listenable(),
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
                      style: TextStyle(
                          color: Theme.of(context).brightness ==
                                  Brightness.dark
                              ? AppColors.pink
                              : AppColors.primaryDark,
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
    final records = DB.termGpas.values.toList()
      ..sort((a, b) =>
          (a.year * 10 + a.term).compareTo(b.year * 10 + b.term));
    final withCum = records.where((r) => r.cumGpa != null).toList();
    final latestCum = withCum.isEmpty ? null : withCum.last.cumGpa;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: t('gradeHistory')),
        // latest cumulative GPA card
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
                    latestCum == null
                        ? Text(t('noGpaYet'),
                            style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                                fontWeight: FontWeight.w700))
                        : Text(latestCum.toStringAsFixed(2),
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 30)),
                  ],
                ),
              ),
              Text('${records.length} ${t('termsRecorded')}',
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (var y = 1; y <= _year; y++) _yearGroup(y),
      ],
    );
  }

  Widget _yearGroup(int year) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_yearName(year),
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 4),
            _termRow(year, 1),
            const Divider(height: 18),
            _termRow(year, 2),
          ],
        ),
      ),
    );
  }

  TermGpa? _findTermGpa(int year, int term) {
    for (final r in DB.termGpas.values) {
      if (r.year == year && r.term == term) return r;
    }
    return null;
  }

  Widget _termRow(int year, int term) {
    final rec = _findTermGpa(year, term);
    final hasAny = rec != null &&
        (rec.termGpa != null || rec.cumGpa != null);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_termName(term),
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 2),
              if (!hasAny)
                Text(t('notEntered'),
                    style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                        fontSize: 12))
              else
                Text(
                  [
                    if (rec!.termGpa != null)
                      '${t('termGpa')}: ${rec.termGpa!.toStringAsFixed(2)}',
                    if (rec.cumGpa != null)
                      '${t('cumGpa')}: ${rec.cumGpa!.toStringAsFixed(2)}',
                  ].join('  •  '),
                  style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant,
                      fontSize: 12),
                ),
            ],
          ),
        ),
        if (rec == null)
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: t('addTerm'),
            onPressed: () =>
                _termGpaSheet(year: year, term: term),
          )
        else ...[
          IconButton(
            icon: const Icon(Icons.edit_rounded, size: 20),
            tooltip: t('editTerm'),
            onPressed: () => _termGpaSheet(existing: rec),
          ),
          IconButton(
            icon: const Icon(Icons.delete_rounded,
                size: 20, color: AppColors.error),
            tooltip: t('delete'),
            onPressed: () async {
              if (await confirmDelete(context,
                  message: t('deleteTerm'))) {
                await DB.termGpas.delete(rec.id);
              }
            },
          ),
        ],
      ],
    );
  }

  /// Local Liquid Glass bottom sheet helper. Kept local to this file so it
  /// can't clash with a shared helper a teammate will add later.
  Future<T?> _showGlassSheet<T>({required Widget child}) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final dark = Theme.of(ctx).brightness == Brightness.dark;
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: AnimatedPadding(
            padding: MediaQuery.of(ctx).viewInsets,
            duration: const Duration(milliseconds: 150),
            child: Container(
              constraints: BoxConstraints(
                maxHeight:
                    MediaQuery.of(ctx).size.height * 0.85,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    cs.surface.withValues(alpha: 0.94),
                    cs.surfaceContainerHighest
                        .withValues(alpha: 0.82),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28)),
                border: Border(
                  top: BorderSide(
                      color: Colors.white
                          .withValues(alpha: dark ? 0.16 : 0.55),
                      width: 1.2),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.28),
                    blurRadius: 32,
                    offset: const Offset(0, -10),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // drag handle
                    Padding(
                      padding: const EdgeInsets.only(
                          top: 10, bottom: 2),
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: cs.onSurfaceVariant
                              .withValues(alpha: 0.4),
                          borderRadius:
                              BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    Flexible(
                      child:
                          SingleChildScrollView(child: child),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Add / edit form for one term's GPAs (Liquid Glass bottom sheet).
  Future<void> _termGpaSheet(
      {int year = 1, int term = 1, TermGpa? existing}) async {
    var y = (existing?.year ?? year).clamp(1, 7);
    var tm = (existing?.term ?? term).clamp(1, 2);
    final termC = TextEditingController(
        text: existing?.termGpa != null ? '${existing!.termGpa}' : '');
    final cumC = TextEditingController(
        text: existing?.cumGpa != null ? '${existing!.cumGpa}' : '');
    final ok = await _showGlassSheet<bool>(
      child: StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text(
                    existing == null
                        ? t('addTerm')
                        : t('editTerm'),
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17)),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: LabeledDropdown<int>(
                      label: t('academicYear'),
                      value: y,
                      items: [
                        for (var i = 1; i <= 7; i++)
                          DropdownMenuItem(
                              value: i,
                              child: Text(_yearName(i))),
                      ],
                      onChanged: (v) => setSheet(
                          () => y = (v ?? 1).clamp(1, 7)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: LabeledDropdown<int>(
                      label: t('term'),
                      value: tm,
                      items: [
                        DropdownMenuItem(
                            value: 1,
                            child: Text(t('term1'))),
                        DropdownMenuItem(
                            value: 2,
                            child: Text(t('term2'))),
                      ],
                      onChanged: (v) => setSheet(
                          () => tm = (v ?? 1).clamp(1, 2)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: termC,
                      keyboardType:
                          const TextInputType.numberWithOptions(
                              decimal: true),
                      decoration: InputDecoration(
                        labelText: t('termGpa'),
                        hintText: t('optional'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: cumC,
                      keyboardType:
                          const TextInputType.numberWithOptions(
                              decimal: true),
                      decoration: InputDecoration(
                        labelText: t('cumGpa'),
                        hintText: t('optional'),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(t('gpaOptionalHint'),
                  style: TextStyle(
                      color: Theme.of(ctx)
                          .colorScheme
                          .onSurfaceVariant,
                      fontSize: 12)),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () =>
                          Navigator.pop(ctx, false),
                      child: Text(t('cancel')),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () =>
                          Navigator.pop(ctx, true),
                      child: Text(t('save')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (ok != true) return;
    double? tg, cg;
    var bad = false;
    final tgRaw = termC.text.trim();
    if (tgRaw.isNotEmpty) {
      tg = double.tryParse(tgRaw);
      if (tg == null || tg < 0 || tg > 5) bad = true;
    }
    final cgRaw = cumC.text.trim();
    if (cgRaw.isNotEmpty) {
      cg = double.tryParse(cgRaw);
      if (cg == null || cg < 0 || cg > 5) bad = true;
    }
    if (bad) {
      if (mounted) showSnack(context, t('invalidGpa'), error: true);
      return;
    }
    final dup = _findTermGpa(y, tm);
    if (dup != null && (existing == null || dup.id != existing.id)) {
      if (mounted) showSnack(context, t('termExists'), error: true);
      return;
    }
    if (existing != null) {
      existing.year = y;
      existing.term = tm;
      existing.termGpa = tg;
      existing.cumGpa = cg;
      await DB.termGpas.put(existing.id, existing);
    } else {
      final id = newId();
      await DB.termGpas.put(
          id,
          TermGpa(
              id: id,
              year: y,
              term: tm,
              termGpa: tg,
              cumGpa: cg));
    }
  }
}
