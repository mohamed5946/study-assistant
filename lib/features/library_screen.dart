import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';
import '../core/ai.dart';
import '../core/l10n.dart';
import '../core/logic.dart';
import '../core/models.dart';
import '../core/schedule_optimizer.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import 'pdf_quiz_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuroraBackground(
        child: ValueListenableBuilder(
          valueListenable: DB.documents.listenable(),
          builder: (_, __, ___) => ValueListenableBuilder(
            valueListenable: DB.subjects.listenable(),
            builder: (_, __, ___) {
              var list = DB.documents.values.toList()
                ..sort((a, b) => b.importedMs.compareTo(a.importedMs));
              if (_filter.isNotEmpty) {
                list = list.where((d) => d.subjectId == _filter).toList();
              }
              return Column(
                children: [
                  SizedBox(
                    height: 52,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: [
                        _chip('', t('all'), _filter.isEmpty),
                        for (final s in DB.subjects.values)
                          _chip(s.id, s.name, _filter == s.id,
                              color: Color(s.colorValue)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: list.isEmpty
                        ? EmptyState(
                            icon: Icons.picture_as_pdf_rounded,
                            message: t('empty'),
                            actionLabel: t('importPdf'),
                            onAction: _import,
                          )
                        : ListView.builder(
                            padding:
                                const EdgeInsets.fromLTRB(16, 8, 16, 100),
                            itemCount: list.length,
                            itemBuilder: (_, i) => _docRow(list[i]),
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _import,
        icon: const Icon(Icons.upload_file_rounded),
        label: Text(t('importPdf')),
      ),
    );
  }

  Widget _chip(String id, String label, bool sel, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: sel,
        onSelected: (_) => setState(() => _filter = sel ? '' : id),
        selectedColor: (color ?? AppColors.primary).withValues(alpha: 0.25),
      ),
    );
  }

  Widget _docRow(StudyDocument d) {
    final sName = DB.subjectName(d.subjectId);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PdfViewerScreen(doc: d)),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.picture_as_pdf_rounded,
                  color: AppColors.error),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
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
              icon:
                  const Icon(Icons.delete_rounded, color: AppColors.error),
              onPressed: () async {
                if (await confirmDelete(context)) {
                  try {
                    await File(d.path).delete();
                  } catch (_) {}
                  await DB.documents.delete(d.id);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _import() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (res == null || res.files.single.path == null) return;
    final src = File(res.files.single.path!);
    final dir = await getApplicationDocumentsDirectory();
    final dest = File(
        '${dir.path}/pdf_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await src.copy(dest.path);

    String subjectId = '';
    final subjects = DB.subjects.values.toList();
    if (subjects.isNotEmpty) {
      if (!mounted) return;
      subjectId = await showDialog<String>(
            context: context,
            builder: (_) => SimpleDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: Text(t('selectSubject')),
              children: [
                for (final s in subjects)
                  SimpleDialogOption(
                    onPressed: () => Navigator.pop(context, s.id),
                    child: Text(s.name),
                  ),
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, ''),
                  child: Text('— ${t('all')} —'),
                ),
              ],
            ),
          ) ??
          '';
    }
    final id = newId();
    await DB.documents.put(
      id,
      StudyDocument(
        id: id,
        subjectId: subjectId,
        name: res.files.single.name,
        path: dest.path,
        importedMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

// ---------------- PDF viewer + AI actions ----------------

class PdfViewerScreen extends StatefulWidget {
  final StudyDocument doc;
  const PdfViewerScreen({super.key, required this.doc});
  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  late PdfController _pdf;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _pdf = PdfController(document: PdfDocument.openFile(widget.doc.path));
  }

  @override
  void dispose() {
    _pdf.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.doc.name,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (_busy)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else ...[
            IconButton(
                icon: const Icon(Icons.psychology_rounded),
                tooltip: t('explain'),
                onPressed: () => _aiAction('explain')),
            IconButton(
                icon: const Icon(Icons.quiz_rounded),
                tooltip: t('genQuestions'),
                onPressed: () => _aiAction('questions')),
            IconButton(
                icon: const Icon(Icons.summarize_rounded),
                tooltip: t('summary'),
                onPressed: () => _aiAction('summary')),
            IconButton(
                icon: const Icon(Icons.question_answer_rounded),
                tooltip: t('askPdf'),
                onPressed: _askPdf),
            IconButton(
                icon: const Icon(Icons.fact_check_rounded),
                tooltip: t('selfTest'),
                onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              PdfSelfTestScreen(doc: widget.doc)),
                    )),
          ],
        ],
      ),
      body: _busy
          ? const Center(child: StudyLoadingBar())
          : PdfView(
              controller: _pdf,
              scrollDirection: Axis.vertical,
            ),
    );
  }

  Future<void> _aiAction(String kind) async {
    final provider = AiService.current();
    if (provider == null) {
      if (mounted) showSnack(context, t('noApiKeyMsg'), error: true);
      return;
    }
    if (provider is! GeminiProvider) {
      if (mounted) showSnack(context, t('pdfNeedsGemini'), error: true);
      return;
    }
    int count = 10;
    String difficulty = 'mixed';
    if (kind == 'questions') {
      final cfg = await _questionConfig();
      if (cfg == null) return;
      count = cfg.$1;
      difficulty = cfg.$2;
    }
    setState(() => _busy = true);
    try {
      final ar = Settings.lang == 'ar';
      final bytes = await File(widget.doc.path).readAsBytes();
      late String prompt;
      if (kind == 'explain') {
        prompt = ar
            ? 'اشرح محتوى ملف الـ PDF المرفق بأسلوب مبسط مع أمثلة، بالعربية. لو المحتوى عن علوم الحاسب/البرمجة، اذكر أمثلة كود قصيرة بالإنجليزية داخل ```code blocks``` مع الشرح بالعربية.'
            : 'Explain the attached PDF content simply with examples, in English. If the content is about computer science/programming, include tiny code examples inside ```code blocks``` where relevant.';
      } else if (kind == 'summary') {
        prompt = ar
            ? 'اعمل ملخص من صفحة واحدة تقريبًا لأهم النقاط في ملف الـ PDF المرفق، بالعربية.'
            : 'Write an approximately one-page summary of the key points in the attached PDF, in English.';
      } else {
        prompt = AiService.questionsPrompt(
            count: count, difficulty: difficulty, ar: ar);
      }
      final out = await provider.analyzePdf(
          pdfBytes: bytes, fileName: widget.doc.name, prompt: prompt);
      if (!mounted) return;
      if (kind == 'questions') {
        _handleQuestions(out);
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AiResultScreen(
              title: kind == 'explain' ? t('explain') : t('summary'),
              text: out,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showSnack(
            context, e is AiException ? e.message : t('sendFailed'),
            error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _askPdf() async {
    final qC = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(t('askPdf')),
        content: TextField(
          controller: qC,
          maxLines: 3,
          decoration: InputDecoration(hintText: t('askPdfHint')),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(t('cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(t('askPdf'))),
        ],
      ),
    );
    if (ok != true || qC.text.trim().isEmpty) return;
    final provider = AiService.current();
    if (provider == null) {
      if (mounted) showSnack(context, t('noApiKeyMsg'), error: true);
      return;
    }
    if (provider is! GeminiProvider) {
      if (mounted) showSnack(context, t('pdfNeedsGemini'), error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final bytes = await File(widget.doc.path).readAsBytes();
      final out = await provider.analyzePdf(
        pdfBytes: bytes,
        fileName: widget.doc.name,
        prompt: AiService.askPdfPrompt(qC.text.trim(),
            ar: Settings.lang == 'ar'),
      );
      if (!mounted) return;
      final pages = extractPageCitations(out);
      final clean = stripPageCitations(out);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AiResultScreen(
            title: t('askPdf'),
            text: clean,
            pages: pages,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        showSnack(context, e is AiException ? e.message : t('sendFailed'),
            error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<(int, String)?> _questionConfig() async {
    int count = 10;
    String diff = 'mixed';
    final diffs = ['easy', 'medium', 'hard', 'mixed'];
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(t('genQuestions')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(t('questionCount')),
                  Expanded(
                    child: Slider(
                      value: count.toDouble(),
                      min: 5,
                      max: 30,
                      divisions: 5,
                      label: '$count',
                      onChanged: (v) =>
                          setS(() => count = v.round()),
                    ),
                  ),
                  Text('$count'),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final d in diffs)
                    ChoiceChip(
                      label: Text(t(d)),
                      selected: diff == d,
                      onSelected: (_) => setS(() => diff = d),
                    ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(t('cancel'))),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(t('generating'))),
          ],
        ),
      ),
    );
    return ok == true ? (count, diff) : null;
  }

  void _handleQuestions(String out) {
    List<QuizQ> qs;
    try {
      qs = parseQuestions(out);
    } catch (_) {
      qs = [];
    }
    if (qs.isEmpty) {
      showSnack(context, t('sendFailed'), error: true);
      return;
    }
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('${qs.length} ✓',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 18)),
              const SizedBox(height: 12),
              GlassButton(
                label: t('saveAsExam'),
                icon: Icons.quiz_rounded,
                onPressed: () async {
                  final id = newId();
                  await DB.exams.put(
                    id,
                    Exam(
                      id: id,
                      title: widget.doc.name,
                      subjectId: widget.doc.subjectId,
                      documentId: widget.doc.id,
                      durationMin: qs.length,
                      questionsJson: jsonEncode(
                          qs.map((q) => q.toJson()).toList()),
                      createdMs:
                          DateTime.now().millisecondsSinceEpoch,
                    ),
                  );
                  if (mounted) {
                    Navigator.pop(context);
                    showSnack(context, '✅');
                  }
                },
              ),
              const SizedBox(height: 10),
              GlassButton(
                label: t('saveAsFlashcards'),
                icon: Icons.style_rounded,
                secondary: true,
                onPressed: () async {
                  final now = DateTime.now().millisecondsSinceEpoch;
                  for (final q in qs) {
                    final id = newId();
                    await DB.flashcards.put(
                      id,
                      Flashcard(
                        id: id,
                        subjectId: widget.doc.subjectId,
                        documentId: widget.doc.id,
                        front: q.q,
                        back: q.answer.isNotEmpty
                            ? q.answer
                            : q.explanation,
                        nextReviewMs: now,
                      ),
                    );
                  }
                  if (mounted) {
                    Navigator.pop(context);
                    showSnack(context, '✅');
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AiResultScreen extends StatelessWidget {
  final String title, text;
  final List<int> pages;
  const AiResultScreen(
      {super.key, required this.title, required this.text, this.pages = const []});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_rounded),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: text));
              showSnack(context, t('copied'));
            },
          ),
        ],
      ),
      body: AuroraBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          children: [
            if (pages.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color:
                                AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.menu_book_rounded,
                              size: 14, color: AppColors.primaryDark),
                          const SizedBox(width: 6),
                          Text(
                            pages.length == 1
                                ? '${t('sourceFile')} (${t('page')} ${pages.first})'
                                : '${t('sourceFile')} (${t('page')}: ${pages.join('، ')})',
                            style: const TextStyle(
                                color: AppColors.primaryDark,
                                fontWeight: FontWeight.w700,
                                fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            GlassCard(
              child: SelectableText(text,
                  style:
                      const TextStyle(fontSize: 15, height: 1.8)),
            ),
          ],
        ),
      ),
    );
  }
}
