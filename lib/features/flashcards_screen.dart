import 'package:flutter/material.dart';
import '../core/l10n.dart';
import '../core/logic.dart';
import '../core/models.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../core/widgets.dart';

class FlashcardsScreen extends StatefulWidget {
  const FlashcardsScreen({super.key});
  @override
  State<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends State<FlashcardsScreen> {
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuroraBackground(
        child: ValueListenableBuilder(
          valueListenable: DB.flashcards.listenable(),
          builder: (_, __, ___) {
            final now = DateTime.now().millisecondsSinceEpoch;
            var all = DB.flashcards.values.toList();
            if (_filter.isNotEmpty) {
              all = all.where((c) => c.subjectId == _filter).toList();
            }
            final due =
                all.where((c) => c.nextReviewMs <= now).toList();
            return Column(
              children: [
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: GlassCard(
                    gradient: const [
                      AppColors.primary,
                      AppColors.violet
                    ],
                    child: Row(
                      children: [
                        const Icon(Icons.style_rounded,
                            color: Colors.white, size: 30),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text('${due.length}',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 26)),
                              Text(t('dueCards'),
                                  style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13)),
                            ],
                          ),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppColors.primary),
                          onPressed: due.isEmpty
                              ? null
                              : () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            ReviewScreen(cards: due)),
                                  ),
                          child: Text(t('startReview')),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: all.isEmpty
                      ? EmptyState(
                          icon: Icons.style_rounded,
                          message: t('empty'),
                          actionLabel: t('addCard'),
                          onAction: () => _editCard(null),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(
                              16, 4, 16, 100),
                          itemCount: all.length,
                          itemBuilder: (_, i) =>
                              _cardRow(all[i], now),
                        ),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editCard(null),
        icon: const Icon(Icons.add_rounded),
        label: Text(t('addCard')),
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

  Widget _cardRow(Flashcard c, int now) {
    final sName = DB.subjectName(c.subjectId);
    final isDue = c.nextReviewMs <= now;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        child: Row(
          children: [
            Container(
              width: 10,
              height: 44,
              decoration: BoxDecoration(
                color: isDue ? AppColors.warning : AppColors.success,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.front,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                  if (sName != null)
                    Text(sName,
                        style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                            fontSize: 12)),
                ],
              ),
            ),
            IconButton(
                icon: const Icon(Icons.edit_rounded),
                onPressed: () => _editCard(c)),
            IconButton(
              icon:
                  const Icon(Icons.delete_rounded, color: AppColors.error),
              onPressed: () async {
                if (await confirmDelete(context)) {
                  await DB.flashcards.delete(c.id);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editCard(Flashcard? c) async {
    final frontC = TextEditingController(text: c?.front ?? '');
    final backC = TextEditingController(text: c?.back ?? '');
    String subjectId = c?.subjectId ?? _filter;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(c == null ? t('addCard') : t('edit')),
          content: Column(
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
                  controller: frontC,
                  maxLines: 3,
                  decoration: InputDecoration(labelText: t('front'))),
              const SizedBox(height: 10),
              TextField(
                  controller: backC,
                  maxLines: 3,
                  decoration: InputDecoration(labelText: t('back'))),
            ],
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
    if (frontC.text.trim().isEmpty || backC.text.trim().isEmpty) {
      if (mounted) showSnack(context, t('fillAllFields'), error: true);
      return;
    }
    final id = c?.id ?? newId();
    await DB.flashcards.put(
      id,
      Flashcard(
        id: id,
        subjectId: subjectId,
        documentId: c?.documentId ?? '',
        front: frontC.text.trim(),
        back: backC.text.trim(),
        nextReviewMs: c?.nextReviewMs ??
            DateTime.now().millisecondsSinceEpoch,
        intervalDays: c?.intervalDays ?? 1,
        ease: c?.ease ?? 2.5,
        reviews: c?.reviews ?? 0,
      ),
    );
  }
}

class ReviewScreen extends StatefulWidget {
  final List<Flashcard> cards;
  const ReviewScreen({super.key, required this.cards});
  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  int _i = 0;
  bool _showBack = false;
  int _known = 0;

  @override
  Widget build(BuildContext context) {
    if (_i >= widget.cards.length) {
      return Scaffold(
        appBar: AppBar(title: Text(t('flashcards'))),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.celebration_rounded,
                  size: 70, color: AppColors.warning),
              const SizedBox(height: 12),
              Text(t('excellent'),
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 22)),
              Text('$_known / ${widget.cards.length}'),
              const SizedBox(height: 20),
              GlassButton(
                  label: t('finish'),
                  onPressed: () => Navigator.pop(context)),
            ],
          ),
        ),
      );
    }
    final c = widget.cards[_i];
    return Scaffold(
      appBar: AppBar(
          title: Text('${_i + 1} / ${widget.cards.length}')),
      body: AuroraBackground(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () =>
                      setState(() => _showBack = !_showBack),
                  child: GlassCard(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: SingleChildScrollView(
                        child: Text(
                          _showBack ? c.back : c.front,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              height: 1.7),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (!_showBack)
                SizedBox(
                  width: double.infinity,
                  child: GlassButton(
                    label: t('showAnswer'),
                    onPressed: () =>
                        setState(() => _showBack = true),
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: GlassButton(
                        label: t('iDontKnow'),
                        secondary: true,
                        onPressed: () => _rate(false),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GlassButton(
                        label: t('iKnow'),
                        onPressed: () => _rate(true),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _rate(bool known) async {
    final c = widget.cards[_i];
    final now = DateTime.now().millisecondsSinceEpoch;
    final r = sm2Update(
      interval: c.intervalDays,
      ease: c.ease,
      reviews: c.reviews,
      known: known,
      nowMs: now,
    );
    c.intervalDays = r.interval;
    c.ease = r.ease;
    c.nextReviewMs = r.nextMs;
    c.reviews = c.reviews + 1;
    await DB.flashcards.put(c.id, c);
    if (known) _known++;
    setState(() {
      _i++;
      _showBack = false;
    });
  }
}
