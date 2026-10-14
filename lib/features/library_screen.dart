import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';
import '../core/ai.dart';
import '../core/book_loader.dart';
import '../core/glass_dialog.dart';
import '../core/glass_sheet.dart';
import '../core/l10n.dart';
import '../core/logic.dart';
import '../core/models.dart';
import '../core/schedule_optimizer.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import 'pdf_quiz_screen.dart';
import 'mind_map_screen.dart';

class LibraryScreen extends StatefulWidget {
  final String initialSubjectId;
  const LibraryScreen({super.key, this.initialSubjectId = ''});
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  late String _filter;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialSubjectId;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: AuroraBackground(
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
              icon: const Icon(Icons.share_rounded),
              tooltip: t('sharePdf'),
              onPressed: () async {
                final f = File(d.path);
                if (await f.exists()) {
                  await Share.shareXFiles([XFile(f.path, name: d.name)]);
                }
              },
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

    String subjectId = _filter;
    final subjects = DB.subjects.values.toList();
    if (subjects.isNotEmpty && _filter.isEmpty) {
      if (!mounted) return;
      subjectId = await showGlassDialog<String>(
            context,
            title: t('selectSubject'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final s in subjects)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, s.id),
                        child: Text(s.name),
                      ),
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, ''),
                    child: Text('— ${t('all')} —'),
                  ),
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
  String? _ocrProgress;

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
              padding: EdgeInsets.all(12),
              child: BookLoader(size: 28),
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
                icon: const Icon(Icons.account_tree_rounded),
                tooltip: t('mindMap'),
                onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              MindMapScreen(document: widget.doc)),
                    )),
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
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const BookLoader(),
                  if (_ocrProgress != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _ocrProgress!,
                      style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            )
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
    int count = 10;
    String difficulty = 'mixed';
    if (kind == 'questions') {
      final cfg = await _questionConfig();
      if (cfg == null) return;
      count = cfg.$1;
      difficulty = cfg.$2;
    }
    setState(() {
      _busy = true;
      _ocrProgress = null;
    });
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
        pdfBytes: bytes,
        fileName: widget.doc.name,
        prompt: prompt,
        onOcrProgress: (done, total) {
          if (mounted) {
            setState(
                () => _ocrProgress = '${t('ocrProcessing')} $done/$total');
          }
        },
      );
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
      if (mounted) {
        setState(() {
          _busy = false;
          _ocrProgress = null;
        });
      }
    }
  }

  Future<void> _askPdf() async {
    final qC = TextEditingController();
    final ok = await showGlassSheet<bool>(
      context,
      Builder(
        builder: (ctx) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: qC,
              maxLines: 3,
              decoration: InputDecoration(hintText: t('askPdfHint')),
            ),
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
                      child: Text(t('askPdf'))),
                ),
              ],
            ),
          ],
        ),
      ),
      title: t('askPdf'),
    );
    if (ok != true || qC.text.trim().isEmpty) return;
    final provider = AiService.current();
    if (provider == null) {
      if (mounted) showSnack(context, t('noApiKeyMsg'), error: true);
      return;
    }
    setState(() {
      _busy = true;
      _ocrProgress = null;
    });
    try {
      final bytes = await File(widget.doc.path).readAsBytes();
      final out = await provider.analyzePdf(
        pdfBytes: bytes,
        fileName: widget.doc.name,
        prompt: AiService.askPdfPrompt(qC.text.trim(),
            ar: Settings.lang == 'ar'),
        onOcrProgress: (done, total) {
          if (mounted) {
            setState(
                () => _ocrProgress = '${t('ocrProcessing')} $done/$total');
          }
        },
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
      if (mounted) {
        setState(() {
          _busy = false;
          _ocrProgress = null;
        });
      }
    }
  }

  Future<(int, String)?> _questionConfig() async {
    int count = 10;
    String diff = 'mixed';
    final diffs = ['easy', 'medium', 'hard', 'mixed'];
    final ok = await showGlassSheet<bool>(
      context,
      StatefulBuilder(
        builder: (ctx, setS) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
                      child: Text(t('generating'))),
                ),
              ],
            ),
          ],
        ),
      ),
      title: t('genQuestions'),
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
    showGlassSheet(
      context,
      Column(
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
                  questionsJson:
                      jsonEncode(qs.map((q) => q.toJson()).toList()),
                  createdMs: DateTime.now().millisecondsSinceEpoch,
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
      title: t('genQuestions'),
    );
  }
}

class AiResultScreen extends StatefulWidget {
  final String title, text;
  final List<int> pages;
  const AiResultScreen(
      {super.key, required this.title, required this.text, this.pages = const []});
  @override
  State<AiResultScreen> createState() => _AiResultScreenState();
}

class _AiResultScreenState extends State<AiResultScreen> {
  bool _searchOpen = false;
  final _searchC = TextEditingController();
  final _scrollC = ScrollController();
  List<int> _matches = [];
  int _current = 0;

  @override
  void dispose() {
    _searchC.dispose();
    _scrollC.dispose();
    super.dispose();
  }

  void _updateSearch(String q) {
    final query = q.trim();
    if (query.isEmpty) {
      setState(() {
        _matches = [];
        _current = 0;
      });
      return;
    }
    final lower = widget.text.toLowerCase();
    final qLower = query.toLowerCase();
    final found = <int>[];
    var i = 0;
    while (true) {
      i = lower.indexOf(qLower, i);
      if (i < 0) break;
      found.add(i);
      i += qLower.length;
    }
    setState(() {
      _matches = found;
      _current = 0;
    });
    if (found.isNotEmpty) _jumpTo(0);
  }

  void _jumpTo(int idx) {
    if (_matches.isEmpty) return;
    final n = _matches.length;
    final wrapped = ((idx % n) + n) % n;
    setState(() => _current = wrapped);
    // Approximate scroll: match offset ratio over total text length.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollC.hasClients) return;
      final ratio = _matches[wrapped] / widget.text.length;
      final max = _scrollC.position.maxScrollExtent;
      _scrollC.animateTo(
        (ratio * max).clamp(0.0, max),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  /// Builds highlighted text spans: yellow for matches, orange for current.
  TextSpan _highlighted() {
    const base =
        TextStyle(fontSize: 15, height: 1.8, color: null);
    if (_matches.isEmpty || _searchC.text.trim().isEmpty) {
      return TextSpan(text: widget.text, style: base);
    }
    final spans = <TextSpan>[];
    final qLen = _searchC.text.trim().length;
    var last = 0;
    for (var k = 0; k < _matches.length; k++) {
      final s = _matches[k];
      if (s > last) {
        spans.add(TextSpan(text: widget.text.substring(last, s), style: base));
      }
      spans.add(TextSpan(
        text: widget.text.substring(s, s + qLen),
        style: base.copyWith(
          backgroundColor: k == _current
              ? const Color(0xFFFF9800).withValues(alpha: 0.55)
              : const Color(0xFFFFEB3B).withValues(alpha: 0.55),
          fontWeight: k == _current ? FontWeight.w700 : null,
        ),
      ));
      last = s + qLen;
    }
    if (last < widget.text.length) {
      spans.add(TextSpan(text: widget.text.substring(last), style: base));
    }
    return TextSpan(children: spans);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: _searchOpen
            ? TextField(
                controller: _searchC,
                autofocus: true,
                onChanged: _updateSearch,
                decoration: InputDecoration(
                  hintText: t('searchInText'),
                  border: InputBorder.none,
                  hintStyle: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant),
                ),
                style: const TextStyle(fontSize: 16),
              )
            : Text(widget.title,
                maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (_searchOpen) ...[
            if (_matches.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Center(
                  child: Text(
                    '${_current + 1} / ${_matches.length}',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700),
                    textDirection: TextDirection.ltr,
                  ),
                ),
              )
            else if (_searchC.text.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Center(
                  child: Text(
                    t('noResults'),
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant),
                  ),
                ),
              ),
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_up_rounded),
              onPressed:
                  _matches.isEmpty ? null : () => _jumpTo(_current - 1),
            ),
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              onPressed:
                  _matches.isEmpty ? null : () => _jumpTo(_current + 1),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () => setState(() {
                _searchOpen = false;
                _searchC.clear();
                _matches = [];
                _current = 0;
              }),
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.search_rounded),
              tooltip: t('searchInText'),
              onPressed: () => setState(() => _searchOpen = true),
            ),
            IconButton(
              icon: const Icon(Icons.copy_rounded),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: widget.text));
                showSnack(context, t('copied'));
              },
            ),
          ],
        ],
      ),
      body: AuroraBackground(
        child: ListView(
          controller: _scrollC,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          children: [
            if (widget.pages.isNotEmpty)
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
                          Icon(Icons.menu_book_rounded,
                              size: 14,
                              color: dark
                                  ? AppColors.pink
                                  : AppColors.primaryDark),
                          const SizedBox(width: 6),
                          Text(
                            widget.pages.length == 1
                                ? '${t('sourceFile')} (${t('page')} ${widget.pages.first})'
                                : '${t('sourceFile')} (${t('page')}: ${widget.pages.join('، ')})',
                            style: TextStyle(
                                color: dark
                                    ? AppColors.pink
                                    : AppColors.primaryDark,
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
              child: SelectableText.rich(
                _highlighted(),
                style:
                    const TextStyle(fontSize: 15, height: 1.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
