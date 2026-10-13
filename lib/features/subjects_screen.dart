import 'package:flutter/material.dart';
import '../core/l10n.dart';
import '../core/models.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../core/widgets.dart';

class SubjectsScreen extends StatelessWidget {
  const SubjectsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t('subjects'))),
      body: AuroraBackground(
        child: ValueListenableBuilder(
          valueListenable: DB.subjects.listenable(),
          builder: (_, __, ___) {
            final list = DB.subjects.values.toList();
            if (list.isEmpty) {
              return EmptyState(
                icon: Icons.book_rounded,
                message: t('empty'),
                actionLabel: t('addSubject'),
                onAction: () => _edit(context, null),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              itemCount: list.length,
              itemBuilder: (_, i) {
                final s = list[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GlassCard(
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: Color(s.colorValue),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: Text(
                              s.name.isNotEmpty ? s.name.characters.first : '?',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 20),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16)),
                              if (s.code.isNotEmpty)
                                Text(s.code,
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                        fontSize: 12)),
                            ],
                          ),
                        ),
                        Text(s.creditHours.toStringAsFixed(s.creditHours.truncateToDouble() == s.creditHours ? 0 : 1),
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15)),
                        IconButton(
                          icon: const Icon(Icons.edit_rounded),
                          onPressed: () => _edit(context, s),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_rounded,
                              color: AppColors.error),
                          onPressed: () async {
                            if (await confirmDelete(context)) {
                              await DB.subjects.delete(s.id);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, null),
        icon: const Icon(Icons.add_rounded),
        label: Text(t('addSubject')),
      ),
    );
  }

  Future<void> _edit(BuildContext context, Subject? s) async {
    final nameC = TextEditingController(text: s?.name ?? '');
    final codeC = TextEditingController(text: s?.code ?? '');
    final chC = TextEditingController(
        text: s != null ? s.creditHours.toString() : '3');
    int color = s?.colorValue ?? AppColors.subjectPalette.first;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(s == null ? t('addSubject') : t('editSubject')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: nameC,
                    decoration:
                        InputDecoration(labelText: t('subjectName'))),
                if (s == null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(t('csPresets'),
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryDark)),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final k in [
                        'csProg', 'csDS', 'csAlgo', 'csDB',
                        'csOS', 'csNet', 'csSE'
                      ])
                        ActionChip(
                          label: Text(t(k),
                              style: const TextStyle(fontSize: 12)),
                          onPressed: () =>
                              setS(() => nameC.text = t(k)),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                TextField(
                    controller: codeC,
                    decoration: InputDecoration(labelText: t('subjectCode'))),
                const SizedBox(height: 10),
                TextField(
                  controller: chC,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration:
                      InputDecoration(labelText: t('creditHours')),
                ),
                const SizedBox(height: 12),
                Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(t('color'))),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final c in AppColors.subjectPalette)
                      GestureDetector(
                        onTap: () => setS(() => color = c),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Color(c),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: color == c
                                  ? Theme.of(ctx).colorScheme.onSurface
                                  : Colors.transparent,
                              width: 3,
                            ),
                          ),
                        ),
                      ),
                  ],
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
    if (nameC.text.trim().isEmpty) {
      if (context.mounted) {
        showSnack(context, t('fillAllFields'), error: true);
      }
      return;
    }
    final ch = double.tryParse(chC.text.trim()) ?? 3;
    if (s == null) {
      final id = newId();
      await DB.subjects.put(
        id,
        Subject(
            id: id, name: nameC.text.trim(), code: codeC.text.trim(),
            colorValue: color, creditHours: ch),
      );
    } else {
      s.name = nameC.text.trim();
      s.code = codeC.text.trim();
      s.colorValue = color;
      s.creditHours = ch;
      await DB.subjects.put(s.id, s);
    }
  }
}
