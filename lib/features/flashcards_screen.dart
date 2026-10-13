import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../core/glass_dialog.dart';
import '../core/l10n.dart';
import '../core/logic.dart';
import '../core/models.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../core/widgets.dart';

class FlashcardsScreen extends StatefulWidget {
  final String initialSubjectId;
  const FlashcardsScreen({super.key, this.initialSubjectId = ''});
  @override
  State<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends State<FlashcardsScreen> {
  late String _filter;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialSubjectId;
  }

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
    final ok = await showGlassDialog<bool>(
      context,
      title: c == null ? t('addCard') : t('edit'),
      content: StatefulBuilder(
        builder: (ctx, setS) => Column(
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
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t('cancel'))),
        FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t('save'))),
      ],
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
                  child: _Flashcard3D(
                    key: ValueKey(c.id),
                    front: c.front,
                    back: c.back,
                    showBack: _showBack,
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

/// 3D flashcard: a raised, branded-blue card that flips with a real
/// perspective rotateY animation to reveal the answer on its back.
///
/// GPU-cheap: ONE [TweenAnimationBuilder] drives the whole flip. All
/// decoration (gradients, shadows, sheens) is static and repaint-cached
/// inside a [RepaintBoundary] — no per-frame blurs or re-layouts.
class _Flashcard3D extends StatelessWidget {
  final String front;
  final String back;
  final bool showBack;

  const _Flashcard3D({
    super.key,
    required this.front,
    required this.back,
    required this.showBack,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return RepaintBoundary(
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: showBack ? 1 : 0),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
        builder: (context, v, _) {
          final angle = v * math.pi;
          // Swap faces exactly when the card is edge-on (v == 0.5) so
          // the swap is invisible mid-flip.
          final showFrontFace = v < 0.5;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0016) // perspective: real 3D depth
              ..rotateY(angle),
            child: showFrontFace
                ? _face(
                    dark: dark,
                    isFront: true,
                    label: t('front'),
                    icon: Icons.help_outline_rounded,
                    text: front,
                    affordanceLabel: t('showAnswer'),
                    affordanceIcon: Icons.visibility_rounded,
                  )
                : Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.rotationY(math.pi),
                    child: _face(
                      dark: dark,
                      isFront: false,
                      label: t('back'),
                      icon: Icons.lightbulb_rounded,
                      text: back,
                      affordanceLabel: t('front'),
                      affordanceIcon: Icons.flip_rounded,
                    ),
                  ),
          );
        },
      ),
    );
  }

  /// One raised card face: layered blue gradients, bright top-edge
  /// highlight, glossy top sheen, bottom vignette, and a soft blue glow
  /// shadow so the card pops OUT of the screen. Never white-on-white:
  /// dark mode uses deep-blue dark surfaces, text is always white.
  Widget _face({
    required bool dark,
    required bool isFront,
    required String label,
    required IconData icon,
    required String text,
    required String affordanceLabel,
    required IconData affordanceIcon,
  }) {
    final gradient = isFront
        ? (dark
            ? const [
                Color(0xFF0E5A8A),
                Color(0xFF075A8A),
                Color(0xFF0B2545)
              ]
            : const [AppColors.pink, AppColors.primary, AppColors.primaryDark])
        : (dark
            ? const [
                Color(0xFF0F766E),
                Color(0xFF0B5A66),
                Color(0xFF0A2733)
              ]
            : const [
                AppColors.secondary,
                AppColors.primary,
                Color(0xFF0B3B66)
              ]);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: dark ? 0.16 : 0.4),
          width: 1.2,
        ),
        boxShadow: [
          // colored glow — the "popping out" halo
          BoxShadow(
            color: AppColors.primary.withValues(alpha: dark ? 0.5 : 0.35),
            blurRadius: 30,
            spreadRadius: 2,
            offset: const Offset(0, 16),
          ),
          // soft grounding shadow
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.55 : 0.18),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            // glossy top sheen
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.center,
                    colors: [
                      Colors.white.withValues(alpha: dark ? 0.14 : 0.22),
                      Colors.white.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
            // bottom vignette for depth
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.center,
                    colors: [
                      Colors.black.withValues(alpha: dark ? 0.25 : 0.12),
                      Colors.black.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
            // bright top-edge highlight line
            Positioned(
              top: 10,
              left: 28,
              right: 28,
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0),
                      Colors.white.withValues(alpha: dark ? 0.5 : 0.7),
                      Colors.white.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
              child: Column(
                children: [
                  // face label pill (question / answer)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                          color:
                              Colors.white.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, color: Colors.white, size: 16),
                        const SizedBox(width: 6),
                        Text(label,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        child: Text(
                          text,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            height: 1.7,
                            shadows: [
                              Shadow(
                                  color: Color(0x55000000),
                                  blurRadius: 8,
                                  offset: Offset(0, 2)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // tap-to-flip affordance pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 9),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                          color:
                              Colors.white.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(affordanceIcon,
                            color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Text(affordanceLabel,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
