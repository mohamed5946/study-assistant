import 'package:flutter/material.dart';
import '../core/l10n.dart';
import '../core/models.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../core/widgets.dart';

class NotesScreen extends StatefulWidget {
  final String initialSubjectId;
  const NotesScreen({super.key, this.initialSubjectId = ''});
  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  String _q = '';
  late String _filter;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialSubjectId;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t('myNotes'))),
      body: AuroraBackground(
        child: ValueListenableBuilder(
          valueListenable: DB.notes.listenable(),
          builder: (_, __, ___) {
            var list = DB.notes.values.toList()
              ..sort((a, b) => b.updatedMs.compareTo(a.updatedMs));
            if (_filter.isNotEmpty) {
              list = list.where((n) => n.subjectId == _filter).toList();
            }
            if (_q.isNotEmpty) {
              final q = _q.toLowerCase();
              list = list
                  .where((n) =>
                      n.title.toLowerCase().contains(q) ||
                      n.text.toLowerCase().contains(q))
                  .toList();
            }
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: t('searchNotes'),
                      prefixIcon: const Icon(Icons.search_rounded),
                    ),
                    onChanged: (v) => setState(() => _q = v),
                  ),
                ),
                SizedBox(
                  height: 52,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      _chip('', t('all'), _filter.isEmpty),
                      for (final s in DB.subjects.values)
                        _chip(s.id, s.name, _filter == s.id),
                    ],
                  ),
                ),
                Expanded(
                  child: list.isEmpty
                      ? EmptyState(
                          icon: Icons.note_alt_rounded,
                          message: t('noNotes'),
                          actionLabel: t('addNote'),
                          onAction: () => _edit(null),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(
                              16, 4, 16, 100),
                          itemCount: list.length,
                          itemBuilder: (_, i) => _row(list[i]),
                        ),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(null),
        icon: const Icon(Icons.add_rounded),
        label: Text(t('addNote')),
      ),
    );
  }

  Widget _chip(String id, String label, bool sel) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: sel,
        onSelected: (_) => setState(() => _filter = sel ? '' : id),
      ),
    );
  }

  Widget _row(Note n) {
    final sName = DB.subjectName(n.subjectId);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        onTap: () => _edit(n),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [AppColors.violet, AppColors.secondary]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.note_alt_rounded,
                  color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(n.title.isEmpty ? '—' : n.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text(
                    '${sName ?? ''} ${sName != null ? '• ' : ''}${n.text.length > 60 ? '${n.text.substring(0, 60)}…' : n.text}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
              icon:
                  const Icon(Icons.delete_rounded, color: AppColors.error),
              onPressed: () async {
                if (await confirmDelete(context,
                    message: t('deleteNote'))) {
                  await DB.notes.delete(n.id);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _edit(Note? n) async {
    final titleC = TextEditingController(text: n?.title ?? '');
    final textC = TextEditingController(text: n?.text ?? '');
    String subjectId = n?.subjectId ?? _filter;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(n == null ? t('addNote') : t('editNote')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LabeledDropdown<String>(
                  value: subjectId.isEmpty ? null : subjectId,
                  items: [
                    DropdownMenuItem(value: '', child: Text('—')),
                    for (final s in DB.subjects.values)
                      DropdownMenuItem(value: s.id, child: Text(s.name)),
                  ],
                  onChanged: (v) => setS(() => subjectId = v ?? ''),
                  label: t('subject'),
                ),
                const SizedBox(height: 10),
                TextField(
                    controller: titleC,
                    decoration: InputDecoration(labelText: t('noteTitle'))),
                const SizedBox(height: 10),
                TextField(
                  controller: textC,
                  maxLines: 8,
                  decoration: InputDecoration(labelText: t('noteText')),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(t('cancel'))),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(t('save'))),
          ],
        ),
      ),
    );
    if (ok != true) return;
    if (textC.text.trim().isEmpty && titleC.text.trim().isEmpty) {
      if (mounted) showSnack(context, t('fillAllFields'), error: true);
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = n?.id ?? newId();
    await DB.notes.put(
      id,
      Note(
        id: id,
        subjectId: subjectId,
        title: titleC.text.trim(),
        text: textC.text.trim(),
        createdMs: n?.createdMs ?? now,
        updatedMs: now,
      ),
    );
  }
}
