import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../core/ai.dart';
import '../core/code_text.dart';
import '../core/l10n.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../core/widgets.dart';

/// Scan Question: photograph a textbook/exam question -> AI solves step by step.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});
  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  File? _image;
  String? _solution;
  bool _busy = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t('scanQuestionTitle'))),
      body: AuroraBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          children: [
            if (_image == null)
              _pickCard()
            else ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.file(_image!, height: 260, fit: BoxFit.cover),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: GlassButton(
                      label: t('solving'),
                      icon: Icons.auto_awesome_rounded,
                      onPressed: _busy ? null : _solve,
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded),
                    tooltip: t('retry'),
                    onPressed: () => setState(() {
                      _image = null;
                      _solution = null;
                      _error = null;
                    }),
                  ),
                ],
              ),
            ],
            if (_busy) ...[
              const SizedBox(height: 20),
              const StudyLoadingBar(),
              const SizedBox(height: 8),
              Center(child: Text(t('solving'))),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.error)),
            ],
            if (_solution != null) ...[
              const SizedBox(height: 16),
              SectionHeader(title: t('solution')),
              GlassCard(
                child: CodeAwareText(
                    text: _solution!,
                    style: const TextStyle(
                        fontSize: 15, height: 1.8)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _pickCard() {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.secondary]),
              boxShadow: [
                BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 20)
              ],
            ),
            child:
                const Icon(Icons.document_scanner_rounded, color: Colors.white, size: 40),
          ),
          const SizedBox(height: 16),
          Text(t('scanQuestionTitle'),
              style:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: GlassButton(
              label: t('takePhoto'),
              icon: Icons.camera_alt_rounded,
              onPressed: () => _pick(ImageSource.camera),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: GlassButton(
              label: t('pickGallery'),
              icon: Icons.image_rounded,
              secondary: true,
              onPressed: () => _pick(ImageSource.gallery),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pick(ImageSource src) async {
    final x = await ImagePicker().pickImage(source: src, maxWidth: 1600);
    if (x == null) return;
    setState(() {
      _image = File(x.path);
      _solution = null;
      _error = null;
    });
  }

  Future<void> _solve() async {
    final provider = AiService.current();
    if (provider == null) {
      setState(() => _error = t('noApiKeyMsg'));
      return;
    }
    if (provider is! GeminiProvider) {
      setState(() => _error = t('pdfNeedsGemini'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final bytes = await _image!.readAsBytes();
      String mime = 'image/jpeg';
      final p = _image!.path.toLowerCase();
      if (p.endsWith('.png')) mime = 'image/png';
      if (p.endsWith('.webp')) mime = 'image/webp';
      final out = await provider.analyzeImage(
        bytes: bytes,
        mimeType: mime,
        prompt: AiService.scanQuestionPrompt(ar: Settings.lang == 'ar'),
      );
      if (!mounted) return;
      setState(() {
        _solution = out;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e is AiException ? e.message : t('sendFailed');
      });
    }
  }
}
