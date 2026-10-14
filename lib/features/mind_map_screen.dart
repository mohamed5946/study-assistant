import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../core/ai.dart';
import '../core/book_loader.dart';
import '../core/l10n.dart';
import '../core/models.dart';
import '../core/pressable_3d.dart';
import '../core/store.dart';
import '../core/theme.dart';

/// Mind Map: AI generates a topic hierarchy from a PDF, rendered as an
/// interactive zoomable map.
class MindMapScreen extends StatefulWidget {
  final StudyDocument document;
  const MindMapScreen({super.key, required this.document});

  @override
  State<MindMapScreen> createState() => _MindMapScreenState();
}

class _MindMapScreenState extends State<MindMapScreen> {
  bool _working = true;
  Map<String, dynamic>? _map;
  String? _error;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    try {
      final bytes = await File(widget.document.path).readAsBytes();
      final provider = AiService.current();
      if (provider == null) throw Exception('No AI provider');
      final raw = await provider.analyzePdf(
        pdfBytes: bytes,
        fileName: widget.document.name,
        prompt: AiService.mindMapPrompt(ar: Settings.lang == 'ar'),
      );
      final parsed = _parseJson(raw);
      if (mounted) setState(() => _map = parsed);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Map<String, dynamic>? _parseJson(String raw) {
    var s = raw.trim()
        .replaceAll('```json', '')
        .replaceAll('```', '')
        .trim();
    final start = s.indexOf('{');
    final end = s.lastIndexOf('}');
    if (start < 0 || end < 0) return null;
    return Map<String, dynamic>.from(
        jsonDecode(s.substring(start, end + 1)) as Map);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t('mindMap'))),
      body: AuroraBackground(
        child: SafeArea(
          bottom: false,
          child: _working
              ? const Center(child: BookLoader(size: 64))
              : _error != null
                  ? _errorView()
                  : _map != null
                      ? _mapView()
                      : _errorView(),
        ),
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 48, color: AppColors.warning),
            const SizedBox(height: 12),
            Text(_error ?? t('error'),
                textAlign: TextAlign.center,
                style: const TextStyle(height: 1.6)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                setState(() {
                  _working = true;
                  _error = null;
                });
                _generate();
              },
              icon: const Icon(Icons.refresh_rounded),
              label: Text(t('retry')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mapView() {
    final topic = '${_map!['topic'] ?? ''}';
    final branches =
        (_map!['branches'] as List? ?? []).cast<Map<String, dynamic>>();
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 3.0,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        child: Column(
          children: [
            // Central topic node
            Pressable3D(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color:
                          AppColors.primary.withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Text(
                  topic,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            // Connector line
            Container(width: 3, height: 24, color: AppColors.primary.withValues(alpha: 0.4)),
            // Branches
            for (var i = 0; i < branches.length; i++)
              _branchCard(branches[i], i),
          ],
        ),
      ),
    );
  }

  Widget _branchCard(Map<String, dynamic> branch, int index) {
    final colors = [
      AppColors.secondary,
      AppColors.success,
      AppColors.warning,
      AppColors.primary,
      const Color(0xFF8B5CF6),
      const Color(0xFFEC4899),
    ];
    final color = colors[index % colors.length];
    final children =
        (branch['children'] as List? ?? []).map((e) => '$e').toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Pressable3D(
        child: GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${branch['label'] ?? ''}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
              if (children.isNotEmpty) ...[
                const SizedBox(height: 10),
                for (final child in children)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6, left: 22),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.6),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            child,
                            style: const TextStyle(
                                fontSize: 14, height: 1.6),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
