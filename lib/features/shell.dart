import 'dart:ui';
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
      _Tab(t('home'), Icons.home_rounded, Icons.home_rounded,
          const DashboardScreen()),
      _Tab(t('timetable'), Icons.calendar_month_outlined,
          Icons.calendar_month_rounded, const TimetableScreen()),
      _Tab(t('ai'), Icons.auto_awesome_outlined, Icons.auto_awesome_rounded,
          const AiChatScreen()),
      _Tab(t('study'), Icons.menu_book_outlined, Icons.menu_book_rounded,
          const StudyScreen()),
      _Tab(t('more'), Icons.grid_view_outlined, Icons.grid_view_rounded,
          const MoreScreen()),
    ];
    return Scaffold(
      // Page entrance animation on every tab switch (fade + gentle slide),
      // keyed by tab index so it replays; IndexedStack keeps page state.
      // SafeArea keeps tab content below the system status bar (edge-to-edge).
      body: SafeArea(
        bottom: false,
        child: TweenAnimationBuilder<double>(
          key: ValueKey(_i),
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
          builder: (context, v, child) => Opacity(
            opacity: v,
            child: Transform.translate(
              offset: Offset(24 * (1 - v), 0),
              child: child,
            ),
          ),
          child: IndexedStack(
            index: _i,
            children: [for (final tb in tabs) tb.page],
          ),
        ),
      ),
      bottomNavigationBar: _LivelyNavBar(
        currentIndex: _i,
        onTap: (v) => TabNav.go(v),
        tabs: tabs,
      ),
    );
  }
}

/// Bottom nav with a press-down spring on every button and an animated
/// selection pill — same lively feel as DeliveryFlow, in brand blue.
class _LivelyNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<_Tab> tabs;

  const _LivelyNavBar({
    required this.currentIndex,
    required this.onTap,
    required this.tabs,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.35 : 0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: dark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.white.withValues(alpha: 0.9),
              border: Border.all(
                color: Colors.white.withValues(alpha: dark ? 0.15 : 0.6),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                for (var i = 0; i < tabs.length; i++)
                  _NavItem(
                    label: tabs[i].label,
                    icon: tabs[i].icon,
                    selectedIcon: tabs[i].selectedIcon,
                    selected: i == currentIndex,
                    onTap: () => onTap(i),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  double _pressScale = 1.0;

  void _down(_) => setState(() => _pressScale = 0.88);
  void _up(_) => setState(() => _pressScale = 1.0);
  void _cancel() => setState(() => _pressScale = 1.0);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: _down,
      onTapUp: _up,
      onTapCancel: _cancel,
      behavior: HitTestBehavior.opaque,
      // Springy press: squishes down on touch, bounces back on release.
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: _pressScale, end: _pressScale),
        duration: const Duration(milliseconds: 160),
        curve: _pressScale < 1.0 ? Curves.easeIn : Curves.elasticOut,
        builder: (context, s, child) =>
            Transform.scale(scale: s, child: child),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: EdgeInsets.symmetric(
              horizontal: widget.selected ? 14 : 10, vertical: 7),
          decoration: widget.selected
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.45),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                )
              : null,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.selected ? widget.selectedIcon : widget.icon,
                size: 24,
                color: widget.selected
                    ? Colors.white
                    : scheme.onSurfaceVariant,
              ),
              const SizedBox(height: 2),
              Text(
                widget.label,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11,
                  fontWeight:
                      widget.selected ? FontWeight.w700 : FontWeight.w500,
                  color: widget.selected
                      ? Colors.white
                      : scheme.onSurfaceVariant,
                ),
              ),
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
  final IconData selectedIcon;
  final Widget page;
  _Tab(this.label, this.icon, this.selectedIcon, this.page);
}
