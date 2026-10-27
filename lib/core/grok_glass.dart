import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'motion.dart';
import 'store.dart';
import 'l10n.dart';
import 'theme.dart';

/// v2.10: Grok Glass widgets, adapted (not pasted) into the app's own
/// design system.
///
/// Rules these widgets follow, all taken from the review of Grok's files:
/// - ONE blue: the app's current [AppColors.primary] family only. Grok's
///   #0A84FF is deliberately NOT used, so screens never ship two blues.
/// - English text uses the platform sans (via the app theme), Arabic uses
///   Cairo — never a Cairo-only hardcode.
/// - Every BackdropFilter sits inside a RepaintBoundary (the DeliveryFlow
///   v27.21 performance lesson).
/// - No `Map<String, dynamic>` data: every widget takes typed parameters.
/// - Lectures/sections wording only, never the forbidden class word.

/// Soft blurred glow blob (Grok's solid-circle glow, fixed: a hard disc
/// has a visible edge; a blurred circle reads as light).
class GrokGlow extends StatelessWidget {
  final Color color;
  final double size;
  const GrokGlow({super.key, required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    if (Settings.reduceAnim) return const SizedBox.shrink();
    return RepaintBoundary(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 48, sigmaY: 48),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
      ),
    );
  }
}

/// Grok's ElasticReveal, fixed: the [delay] parameter actually delays.
///
/// Grok's version declared `delay` but never used it, so staggered
/// entrances never staggered. Here the reveal starts only after [delay]
/// has elapsed (a [Timer] under the hood); with [delay] zero it behaves
/// exactly like an immediate elastic reveal: fade + rise from 36px over
/// ~0.9s on the elastic overshoot curve. When reduce-animations is on,
/// the child appears instantly (or not at all when hidden).
class DelayedElasticReveal extends StatefulWidget {
  final Widget child;
  final bool visible;
  final Duration delay;
  const DelayedElasticReveal({
    super.key,
    required this.child,
    required this.visible,
    this.delay = Duration.zero,
  });

  @override
  State<DelayedElasticReveal> createState() =>
      _DelayedElasticRevealState();
}

class _DelayedElasticRevealState extends State<DelayedElasticReveal> {
  bool _started = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(DelayedElasticReveal old) {
    super.didUpdateWidget(old);
    if (old.visible != widget.visible || old.delay != widget.delay) {
      _schedule();
    }
  }

  void _schedule() {
    _timer?.cancel();
    if (!widget.visible) {
      _started = false;
      return;
    }
    if (widget.delay == Duration.zero) {
      _started = true;
      return;
    }
    _started = false;
    _timer = Timer(widget.delay, () {
      if (mounted) setState(() => _started = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (Settings.reduceAnim) {
      return widget.visible ? widget.child : const SizedBox.shrink();
    }
    final show = widget.visible && _started;
    return AnimatedOpacity(
      opacity: show ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 900),
      curve: elasticCurve,
      child: AnimatedSlide(
        offset: show ? Offset.zero : const Offset(0, 0.12),
        duration: const Duration(milliseconds: 900),
        curve: elasticCurve,
        child: widget.child,
      ),
    );
  }
}

/// Small room chip for timeline rows (mockup: "204", "305" chips).
class RoomChip extends StatelessWidget {
  final String room;
  const RoomChip({super.key, required this.room});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: dark ? 0.25 : 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.location_on_rounded,
              size: 13, color: AppColors.primary),
          const SizedBox(width: 3),
          Flexible(
            child: Text(room,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary)),
          ),
        ],
      ),
    );
  }
}

/// Gradient next-lecture card from the mockups: clock icon, title,
/// time + place, and a status pill ("in 45 min" / "now"). All values are
/// typed parameters supplied by the caller from real timetable data —
/// never demo data, never a hardcoded name or subject.
class NextLectureCard extends StatelessWidget {
  final String title;
  final String kindLabel;
  final String timeLabel;
  final String? place;
  final String statusText;
  final VoidCallback? onTap;
  const NextLectureCard({
    super.key,
    required this.title,
    required this.kindLabel,
    required this.timeLabel,
    required this.statusText,
    this.place,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // No Hero here on purpose: this card navigates to a tab, not to a
    // detail screen, so there is no matching Hero destination — and a
    // Hero flight must never carry a BackdropFilter child (see motion.dart).
    return PressScale(
      onTap: onTap,
      child: GlassCard(
        padding: EdgeInsets.zero,
        gradient: const [AppColors.primary, AppColors.primaryDark],
        child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.school_rounded,
                        color: Colors.white70, size: 18),
                    const SizedBox(width: 6),
                    Text(kindLabel,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13)),
                    const Spacer(),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.22),
                      ),
                      child: const Icon(Icons.access_time_rounded,
                          color: Colors.white, size: 22),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(timeLabel,
                    style: const TextStyle(color: Colors.white, fontSize: 13)),
                if (place != null && place!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(place!,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13)),
                ],
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(statusText,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 12)),
                ),
              ],
            ),
          ),
        ),
    );
  }
}

/// Suggested-prompt chips that actually call back (Grok's ChatUI declared
/// an onSuggestedPrompt callback but never rendered any chip for it).
/// Tapping a chip invokes [onSuggestedPrompt] with the full prompt text;
/// the caller decides what to do with it (the app fills the input).
class SuggestedPromptsRow extends StatelessWidget {
  final List<({String label, String prompt})> prompts;
  final ValueChanged<String> onSuggestedPrompt;
  const SuggestedPromptsRow({
    super.key,
    required this.prompts,
    required this.onSuggestedPrompt,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: [
        for (final p in prompts)
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              HapticFeedback.selectionClick();
              onSuggestedPrompt(p.prompt);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: dark
                    ? Colors.white.withValues(alpha: 0.10)
                    : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.25)),
              ),
              child: Text(p.label,
                  style: TextStyle(
                      color: dark ? Colors.white : AppColors.primaryDark,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
            ),
          ),
      ],
    );
  }
}

/// Pomodoro phases, as a pure function so it is unit-testable without a
/// widget tree or Hive: a finished focus session moves to a break, and
/// every 4th finished focus session earns a long break instead of a
/// short one. A finished break always returns to focus.
enum PomodoroPhase { focus, shortBreak, longBreak }

PomodoroPhase nextPomodoroPhase({
  required bool wasFocus,
  required int finishedFocusCount,
}) {
  if (!wasFocus) return PomodoroPhase.focus;
  if (finishedFocusCount > 0 && finishedFocusCount % 4 == 0) {
    return PomodoroPhase.longBreak;
  }
  return PomodoroPhase.shortBreak;
}

int pomodoroPhaseMinutes(
  PomodoroPhase phase, {
  required int focusMin,
  required int breakMin,
  required int longBreakMin,
}) {
  switch (phase) {
    case PomodoroPhase.focus:
      return focusMin;
    case PomodoroPhase.shortBreak:
      return breakMin;
    case PomodoroPhase.longBreak:
      return longBreakMin;
  }
}

/// v2.11: mockup timeline row — time column, dotted spine, title,
/// subtitle, and a room chip. Pure Column/Row layout (no Stack), so
/// nothing can sit on top of anything else.
class TimelineClassRow extends StatelessWidget {
  final String startLabel;
  final String endLabel;
  final String title;
  final String subtitle;
  final String? room;
  final Color color;
  final VoidCallback? onTap;
  const TimelineClassRow({
    super.key,
    required this.startLabel,
    required this.endLabel,
    required this.title,
    required this.subtitle,
    this.room,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final row = IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 62,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(startLabel,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 2),
                Text(endLabel,
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(top: 4),
                decoration:
                    BoxDecoration(shape: BoxShape.circle, color: color),
              ),
              Expanded(
                child: Container(
                    width: 2,
                    color: color.withValues(alpha: 0.3)),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant)),
                if (room != null && room!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [Flexible(child: RoomChip(room: room!))],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: onTap == null
          ? row
          : InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onTap,
              child: row,
            ),
    );
  }
}

/// Sunday of the week containing [d] (Sunday-first weeks, mockup order).
DateTime weekSunday(DateTime d) {
  final day = DateTime(d.year, d.month, d.day);
  return day.subtract(Duration(days: d.weekday % 7));
}

/// The week's days, Sunday first: (weekday 7,1,2,3,4,5,6) with dates.
List<({int weekday, DateTime date})> weekDaysSundayFirst(DateTime d) {
  final sunday = weekSunday(d);
  const order = [7, 1, 2, 3, 4, 5, 6];
  return [
    for (var i = 0; i < 7; i++)
      (weekday: order[i], date: sunday.add(Duration(days: i))),
  ];
}

/// Cycle through suggested-prompt sets (mockup Refresh button).
int nextPromptSetIndex(int current, int count) =>
    count <= 0 ? 0 : (current + 1) % count;

/// Mockup duration chip: label + minutes, gradient when selected.
class DurationChip extends StatelessWidget {
  final String label;
  final int minutes;
  final bool selected;
  final VoidCallback? onTap;
  const DurationChip({
    super.key,
    required this.label,
    required this.minutes,
    required this.selected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark])
              : null,
          color: selected
              ? null
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.25)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$minutes ${t('minutesShort')}',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: selected
                        ? Colors.white
                        : Theme.of(context).colorScheme.onSurface)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: selected
                        ? Colors.white70
                        : Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

/// Mockup pomodoro ring: progress arc with centered content.
class MockupRing extends StatelessWidget {
  final double progress;
  final double size;
  final Color color;
  final Widget child;
  const MockupRing({
    super.key,
    required this.progress,
    required this.size,
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              strokeWidth: 16,
              backgroundColor:
                  AppColors.primary.withValues(alpha: 0.12),
              color: color,
            ),
          ),
          child,
        ],
      ),
    );
  }
}
