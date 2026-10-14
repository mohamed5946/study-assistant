import 'package:flutter/material.dart';
import '../core/l10n.dart';
import '../core/nav.dart';
import '../core/theme.dart';
import '../core/pressable_3d.dart';
import 'subjects_screen.dart';
import 'deadlines_screen.dart';
import 'attendance_screen.dart';
import 'gpa_screen.dart';
import 'notes_screen.dart';
import 'pomodoro_screen.dart';
import 'planner_screen.dart';
import 'profile_screen.dart';
import 'scan_screen.dart';
import 'settings_screen.dart';

class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});
  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  @override
  void initState() {
    super.initState();
    TabNav.moreTarget.addListener(_onTarget);
  }

  void _onTarget() {
    final v = TabNav.moreTarget.value;
    if (v == null || !mounted) return;
    TabNav.moreTarget.value = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final page = _pages[v];
      if (page != null) _open(context, page);
    });
  }

  @override
  void dispose() {
    TabNav.moreTarget.removeListener(_onTarget);
    super.dispose();
  }

  static final _pages = <String, Widget>{
    'profile': const ProfileScreen(),
    'subjects': const SubjectsScreen(),
    'deadlines': const DeadlinesScreen(),
    'attendance': const AttendanceScreen(),
    'gpa': const GpaScreen(),
    'notes': const NotesScreen(),
    'pomodoro': const PomodoroScreen(),
    'planner': const PlannerScreen(),
    'scan': const ScanScreen(),
    'settings': const SettingsScreen(),
  };

  /// Opens a page with a soft fade + scale-up entrance.
  void _open(BuildContext context, Widget page) {
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 280),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (_, anim, __, child) {
          final curved =
              CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.96, end: 1.0).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      _Item(t('profile'), Icons.person_rounded, 'profile',
          const [AppColors.primary, AppColors.primaryDark]),
      _Item(t('subjects'), Icons.book_rounded, 'subjects',
          const [AppColors.primary, AppColors.secondary]),
      _Item(t('deadlines'), Icons.event_rounded, 'deadlines',
          const [AppColors.pink, AppColors.violet]),
      _Item(t('attendance'), Icons.fact_check_rounded, 'attendance',
          const [AppColors.success, AppColors.secondary]),
      _Item(t('gpa'), Icons.grade_rounded, 'gpa',
          const [AppColors.secondary, AppColors.primaryDark]),
      _Item(t('myNotes'), Icons.note_alt_rounded, 'notes',
          const [AppColors.violet, AppColors.secondary]),
      _Item(t('pomodoro'), Icons.timer_rounded, 'pomodoro',
          const [AppColors.primary, AppColors.violet]),
      _Item(t('studyPlanner'), Icons.calendar_month_rounded, 'planner',
          const [AppColors.primaryDark, AppColors.secondary]),
      _Item(t('scanQuestion'), Icons.document_scanner_rounded, 'scan',
          const [AppColors.warning, AppColors.secondary]),
      _Item(t('settings'), Icons.settings_rounded, 'settings',
          const [Color(0xFF7890AD), Color(0xFF546E7A)]),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(t('more'))),
      body: AuroraBackground(
        child: GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.25,
          ),
          itemCount: items.length,
          itemBuilder: (_, i) {
            final it = items[i];
            return Pressable3D(
              onTap: () => _open(context, _pages[it.key]!),
              child: GlassCard(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: it.gradient),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: it.gradient.first.withValues(alpha: 0.35),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Icon(it.icon, color: Colors.white, size: 28),
                    ),
                    const SizedBox(height: 10),
                    Text(it.label,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Item {
  final String label;
  final IconData icon;
  final String key;
  final List<Color> gradient;
  _Item(this.label, this.icon, this.key, this.gradient);
}
