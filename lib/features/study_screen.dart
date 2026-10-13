import 'package:flutter/material.dart';
import '../core/l10n.dart';
import '../core/nav.dart';
import 'library_screen.dart';
import 'flashcards_screen.dart';
import 'exams_screen.dart';

class StudyScreen extends StatefulWidget {
  const StudyScreen({super.key});
  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen>
    with SingleTickerProviderStateMixin {
  late TabController _c;

  @override
  void initState() {
    super.initState();
    _c = TabController(length: 3, vsync: this);
    TabNav.studyTarget.addListener(_onTarget);
  }

  void _onTarget() {
    final v = TabNav.studyTarget.value;
    if (v == null) return;
    final idx = {'flashcards': 1, 'exams': 2}[v] ?? 0;
    if (mounted) _c.animateTo(idx);
    TabNav.studyTarget.value = null;
  }

  @override
  void dispose() {
    TabNav.studyTarget.removeListener(_onTarget);
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t('study')),
        bottom: TabBar(
          controller: _c,
          labelStyle:
              const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700),
          unselectedLabelStyle: const TextStyle(fontFamily: 'Cairo'),
          tabs: [
            Tab(icon: const Icon(Icons.picture_as_pdf_rounded), text: t('library')),
            Tab(icon: const Icon(Icons.style_rounded), text: t('flashcards')),
            Tab(icon: const Icon(Icons.quiz_rounded), text: t('myExams')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _c,
        children: const [
          LibraryScreen(),
          FlashcardsScreen(),
          ExamsScreen(),
        ],
      ),
    );
  }
}
