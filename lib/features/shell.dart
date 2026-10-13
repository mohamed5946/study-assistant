import 'package:flutter/material.dart';
import '../core/l10n.dart';
import '../core/nav.dart';
import '../core/theme.dart';
import 'dashboard_screen.dart';
import 'timetable_screen.dart';
import 'ai_chat_screen.dart';
import 'study_screen.dart';
import 'more_screen.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _i = 0;

  @override
  void initState() {
    super.initState();
    TabNav.tab.addListener(_onTab);
  }

  void _onTab() {
    if (mounted) setState(() => _i = TabNav.tab.value);
  }

  @override
  void dispose() {
    TabNav.tab.removeListener(_onTab);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      _Tab(t('home'), Icons.home_rounded, const DashboardScreen()),
      _Tab(t('timetable'), Icons.calendar_month_rounded, const TimetableScreen()),
      _Tab(t('ai'), Icons.auto_awesome_rounded, const AiChatScreen()),
      _Tab(t('study'), Icons.menu_book_rounded, const StudyScreen()),
      _Tab(t('more'), Icons.grid_view_rounded, const MoreScreen()),
    ];
    return Scaffold(
      body: IndexedStack(
        index: _i,
        children: [for (final tb in tabs) tb.page],
      ),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BottomNavigationBar(
            currentIndex: _i,
            onTap: (v) => TabNav.go(v),
            type: BottomNavigationBarType.fixed,
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.9),
            selectedItemColor: AppColors.primary,
            unselectedItemColor:
                Theme.of(context).colorScheme.onSurfaceVariant,
            selectedLabelStyle: const TextStyle(
                fontFamily: 'Cairo', fontWeight: FontWeight.w700, fontSize: 12),
            unselectedLabelStyle:
                const TextStyle(fontFamily: 'Cairo', fontSize: 12),
            elevation: 0,
            items: [
              for (final tb in tabs)
                BottomNavigationBarItem(icon: Icon(tb.icon), label: tb.label),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tab {
  final String label;
  final IconData icon;
  final Widget page;
  _Tab(this.label, this.icon, this.page);
}
