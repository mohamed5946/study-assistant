import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../core/ai.dart';
import '../core/book_loader.dart';
import '../core/glass_dialog.dart';
import '../core/l10n.dart';
import '../core/models.dart';
import '../core/pressable_3d.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../core/widgets.dart';

/// PDF Questions Solver: upload a questions PDF inside a subject, AI extracts
/// the questions as-written and solves them using the subject's other PDFs.
class PdfSolverScreen extends StatefulWidget {
  final Subject subject;
  const PdfSolverScreen({super.key, required this.subject});

  @override
  State<PdfSolverScreen> createState() => _PdfSolverScreenState();
}

class _PdfSolverScreenState extends State<PdfSolverScreen> {
  bool _working = false;
  String? _fileName;
  List<Map<String, dynamic>> _solved = [];
  final Set<int> _revealed = {};

  Future<void> _pickAndSolve() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (res == null || res.files.single.path == null) return;
    final path = res.files.single.path!;
    final name = res.files.single.name;
    setState(() {
      _working = true;
      _fileName = name;
      _solved = [];
      _revealed.clear();
    });
    try {
      final qBytes = await File(path).readAsBytes();
      // Gather other PDFs of the same subject as knowledge base.
      final materials = <({String name, List<int> bytes})>[];
      for (final d in DB.documents.values) {
        if (d.subjectId != widget.subject.id) continue;
        try {
          final b = await File(d.path).readAsBytes();
          materials.add((name: d.name, bytes: b));
        } catch (_) {}
        if (materials.length >= 5) break; // cap for context budget
      }
      final provider = AiService.current();
      if (provider == null) throw Exception('No AI provider');
      final raw = await provider.solveQuestions(
        questionsPdfBytes: qBytes,
        questionsFileName: name,
        materialPdfs: materials,
      );
      final parsed = _parseJsonArray(raw);
      setState(() => _solved = parsed);
    } catch (e) {
      if (mounted) {
        await showGlassDialog(
          context,
          title: t('error'),
          content: Text('$e', textAlign: TextAlign.center),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: Text(t('ok')),
            ),
          ],
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  List<Map<String, dynamic>> _parseJsonArray(String raw) {
    var s = raw.trim();
    // Strip markdown fences if the model added them.
    s = s.replaceAll('```json', '').replaceAll('```', '').trim();
    final start = s.indexOf('[');
    final end = s.lastIndexOf(']');
    if (start < 0 || end < 0) return [];
    final arr = jsonDecode(s.substring(start, end + 1)) as List;
    return arr.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t('pdfQuestions'))),
      body: AuroraBackground(
        child: SafeArea(
          bottom: false,
          child: _working
              ? const Center(child: BookLoader(size: 64))
              : _solved.isEmpty
                  ? _emptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                      itemCount: _solved.length + 1,
                      itemBuilder: (_, i) {
                        if (i == 0) return _header();
                        return _questionCard(i - 1, _solved[i - 1]);
                      },
                    ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _working ? null : _pickAndSolve,
        icon: const Icon(Icons.upload_file_rounded),
        label: Text(t('uploadQuestionsPdf')),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        child: Row(
          children: [
            const Icon(Icons.quiz_rounded, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_fileName ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text(
                    '${_solved.length} ${t('question')}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: _working ? null : _pickAndSolve,
              child: Text(t('changeFile')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.12),
              ),
              child: const Icon(Icons.quiz_rounded,
                  size: 44, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              t('pdfSolverHint'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.7,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _pickAndSolve,
              icon: const Icon(Icons.upload_file_rounded),
              label: Text(t('uploadQuestionsPdf')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _questionCard(int index, Map<String, dynamic> q) {
    final revealed = _revealed.contains(index);
    final type = (q['type'] ?? 'written').toString();
    final options = (q['options'] as List? ?? []).map((e) => '$e').toList();
    final correctIndex = (q['correctIndex'] as num?)?.toInt() ?? -1;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Pressable3D(
        child: GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${t('question')} ${index + 1}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '${q['question'] ?? ''}',
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 15, height: 1.6),
              ),
              if (type == 'mcq' && options.isNotEmpty) ...[
                const SizedBox(height: 10),
                for (var i = 0; i < options.length; i++)
                  _optionRow(options[i], i, correctIndex, revealed),
              ],
              const SizedBox(height: 10),
              if (!revealed)
                OutlinedButton.icon(
                  onPressed: () =>
                      setState(() => _revealed.add(index)),
                  icon: const Icon(Icons.visibility_rounded, size: 18),
                  label: Text(t('showAnswer')),
                )
              else ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.success.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.check_circle_rounded,
                              color: AppColors.success, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            t('answer'),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${q['answer'] ?? ''}',
                        style:
                            const TextStyle(fontSize: 14, height: 1.7),
                      ),
                      if ((q['explanation'] ?? '').toString().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          '${q['explanation']}',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.6,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      setState(() => _revealed.remove(index)),
                  child: Text(t('hideAnswer')),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _optionRow(
      String option, int i, int correctIndex, bool revealed) {
    final isCorrect = revealed && i == correctIndex;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isCorrect
            ? AppColors.success.withValues(alpha: 0.12)
            : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCorrect
              ? AppColors.success
              : Theme.of(context).dividerColor.withValues(alpha: 0.5),
          width: isCorrect ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          if (isCorrect)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(Icons.check_circle_rounded,
                  color: AppColors.success, size: 20),
            ),
          Expanded(
            child: Text(option,
                style: TextStyle(
                  fontWeight:
                      isCorrect ? FontWeight.w800 : FontWeight.w500,
                  color: isCorrect
                      ? AppColors.success
                      : null,
                )),
          ),
        ],
      ),
    );
  }
}
