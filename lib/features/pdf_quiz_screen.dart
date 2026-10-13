import 'dart:io';
import 'package:flutter/material.dart';
import '../core/ai.dart';
import '../core/l10n.dart';
import '../core/logic.dart';
import '../core/models.dart';
import '../core/schedule_optimizer.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../core/widgets.dart';

/// PDF self-test: AI extracts the PDF's OWN questions.
/// Per question: user taps THEIR answer first -> "AI answer" reveals the
/// correct one -> "Why this answer?" shows AI reasoning. Score + review at end.
class PdfSelfTestScreen extends StatefulWidget {
  final StudyDocument doc;
  const PdfSelfTestScreen({super.key, required this.doc});
  @override
  State<PdfSelfTestScreen> createState() => _PdfSelfTestScreenState();
}

class _PdfSelfTestScreenState extends State<PdfSelfTestScreen> {
  bool _loading = true;
  String? _error;
  List<QuizQ> _qs = [];
  int _idx = 0;
  final Map<int, String> _userAnswers = {};
  final Set<int> _revealed = {};
  final Set<int> _showWhy = {};
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _extract();
  }

  Future<void> _extract() async {
    final provider = AiService.current();
    if (provider == null) {
      setState(() {
        _loading = false;
        _error = t('noApiKeyMsg');
      });
      return;
    }
    if (provider is! GeminiProvider) {
      setState(() {
        _loading = false;
        _error = t('pdfNeedsGemini');
      });
      return;
    }
    try {
      final bytes = await File(widget.doc.path).readAsBytes();
      final out = await provider.analyzePdf(
        pdfBytes: bytes,
        fileName: widget.doc.name,
        prompt: AiService.extractPdfQuestionsPrompt(
            ar: Settings.lang == 'ar'),
      );
      final qs = parseQuestions(out)
          .where((q) => q.q.trim().isNotEmpty && q.options.isNotEmpty)
          .toList();
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (qs.isEmpty) {
          _error = t('noQuestionsFound');
        } else {
          _qs = qs;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is AiException ? e.message : t('sendFailed');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t('selfTest'))),
      body: AuroraBackground(
        child: _loading
            ? _loadingBody()
            : _error != null
                ? _errorBody()
                : _finished
                    ? _resultBody()
                    : _quizBody(),
      ),
    );
  }

  Widget _loadingBody() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const StudyLoadingBar(),
            const SizedBox(height: 20),
            Text(t('extractingQuestions'),
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _errorBody() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_rounded,
                size: 64, color: AppColors.lightMuted),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            GlassButton(
                label: t('retry'),
                icon: Icons.refresh_rounded,
                onPressed: () =>
                    setState(() { _loading = true; _error = null; _extract(); })),
          ],
        ),
      ),
    );
  }

  Widget _quizBody() {
    final q = _qs[_idx];
    final revealed = _revealed.contains(_idx);
    final userAns = _userAnswers[_idx];
    final progress = (_idx + 1) / _qs.length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      children: [
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor:
                      AppColors.primary.withValues(alpha: 0.15),
                  valueColor: const AlwaysStoppedAnimation(
                      AppColors.primary),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text('${_idx + 1} ${t('stepOf')} ${_qs.length}',
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 16),
        GlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (q.page > 0)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${t('page')} ${q.page}',
                      style: const TextStyle(
                          color: AppColors.primaryDark,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ),
              Text(q.q,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 17, height: 1.6)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (final opt in q.options) _optionTile(q, opt, revealed, userAns),
        const SizedBox(height: 16),
        if (!revealed) ...[
          if (userAns == null)
            Center(
              child: Text(t('tapYourAnswer'),
                  style: TextStyle(
                      color:
                          Theme.of(context).colorScheme.onSurfaceVariant)),
            )
          else
            SizedBox(
              width: double.infinity,
              child: GlassButton(
                label: t('revealAiAnswer'),
                icon: Icons.auto_awesome_rounded,
                onPressed: () =>
                    setState(() => _revealed.add(_idx)),
              ),
            ),
        ] else ...[
          _revealCard(q, userAns),
          const SizedBox(height: 10),
          if (!_showWhy.contains(_idx))
            SizedBox(
              width: double.infinity,
              child: GlassButton(
                label: t('whyThisAnswer'),
                icon: Icons.psychology_rounded,
                secondary: true,
                onPressed: () =>
                    setState(() => _showWhy.add(_idx)),
              ),
            )
          else
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t('aiReasoning'),
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryDark)),
                  const SizedBox(height: 6),
                  Text(
                      q.explanation.isNotEmpty
                          ? q.explanation
                          : t('empty'),
                      style:
                          const TextStyle(fontSize: 14, height: 1.7)),
                ],
              ),
            ),
        ],
        const SizedBox(height: 20),
        Row(
          children: [
            if (_idx > 0)
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: Text(t('prev')),
                  onPressed: () => setState(() => _idx--),
                ),
              ),
            if (_idx > 0) const SizedBox(width: 12),
            Expanded(
              child: GlassButton(
                label: _idx == _qs.length - 1 ? t('finish') : t('next'),
                icon: Icons.arrow_forward_rounded,
                onPressed: () {
                  if (_idx == _qs.length - 1) {
                    setState(() => _finished = true);
                  } else {
                    setState(() => _idx++);
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _optionTile(
      QuizQ q, String opt, bool revealed, String? userAns) {
    final isUserPick = userAns == opt;
    final isCorrect =
        revealed && opt.trim().toLowerCase() == q.answer.trim().toLowerCase();
    final isWrongPick = revealed && isUserPick && !isCorrect;
    Color border = Colors.transparent;
    Color? bg;
    IconData? icon;
    Color iconColor = Colors.white;
    if (revealed) {
      if (isCorrect) {
        border = AppColors.success;
        bg = AppColors.success.withValues(alpha: 0.12);
        icon = Icons.check_rounded;
        iconColor = AppColors.success;
      } else if (isWrongPick) {
        border = AppColors.error;
        bg = AppColors.error.withValues(alpha: 0.10);
        icon = Icons.close_rounded;
        iconColor = AppColors.error;
      }
    } else if (isUserPick) {
      border = AppColors.primary;
      bg = AppColors.primary.withValues(alpha: 0.10);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: revealed
            ? null
            : () => setState(() => _userAnswers[_idx] = opt),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: bg ?? Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: border == Colors.transparent
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : border,
                width: isUserPick || revealed ? 2 : 1),
            boxShadow: [
              BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                  child: Text(opt,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600))),
              if (icon != null) Icon(icon, color: iconColor),
              if (!revealed && isUserPick)
                const Icon(Icons.check_circle_rounded,
                    color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _revealCard(QuizQ q, String? userAns) {
    final correct = userAns != null &&
        userAns.trim().toLowerCase() == q.answer.trim().toLowerCase();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (correct ? AppColors.success : AppColors.primary)
            .withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: correct ? AppColors.success : AppColors.primary,
            width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                  correct
                      ? Icons.check_circle_rounded
                      : Icons.info_rounded,
                  color:
                      correct ? AppColors.success : AppColors.primary),
              const SizedBox(width: 8),
              Text(t('revealAiAnswer'),
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 8),
          Text(q.answer,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _resultBody() {
    final aiAnswers = _qs.map((q) => q.answer).toList();
    final r = scoreSelfTest(aiAnswers, _userAnswers);
    final pct = r.total == 0 ? 0 : (r.correct / r.total * 100).round();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
      children: [
        Center(
          child: Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(colors: [
                AppColors.primary,
                AppColors.secondary
              ]),
              boxShadow: [
                BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    blurRadius: 30)
              ],
            ),
            child: Center(
              child: Text('$pct%',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 36)),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text('${t('yourScore')}: ${r.correct} / ${r.total}',
              style:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        ),
        const SizedBox(height: 8),
        Center(child: Text(t('quizFinished'))),
        const SizedBox(height: 20),
        SectionHeader(title: t('reviewAnswers')),
        for (var i = 0; i < _qs.length; i++) _reviewRow(i),
        const SizedBox(height: 20),
        GlassButton(
          label: t('retry'),
          icon: Icons.refresh_rounded,
          onPressed: () => setState(() {
            _idx = 0;
            _userAnswers.clear();
            _revealed.clear();
            _showWhy.clear();
            _finished = false;
          }),
        ),
      ],
    );
  }

  Widget _reviewRow(int i) {
    final q = _qs[i];
    final userAns = _userAnswers[i];
    final correct = userAns != null &&
        userAns.trim().toLowerCase() == q.answer.trim().toLowerCase();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                    correct
                        ? Icons.check_circle_rounded
                        : Icons.cancel_rounded,
                    color:
                        correct ? AppColors.success : AppColors.error,
                    size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(q.q,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('${t('yourAnswer')}: ${userAns ?? '—'}',
                style: const TextStyle(fontSize: 13)),
            Text('${t('correctAnswer')}: ${q.answer}',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDark)),
          ],
        ),
      ),
    );
  }
}
