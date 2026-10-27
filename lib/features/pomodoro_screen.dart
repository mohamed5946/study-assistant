import 'dart:async';
import 'package:flutter/material.dart';
import '../core/grok_glass.dart';
import '../core/l10n.dart';
import '../core/models.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../core/widgets.dart';

class PomodoroScreen extends StatefulWidget {
  final String initialSubjectId;
  const PomodoroScreen({super.key, this.initialSubjectId = ''});
  @override
  State<PomodoroScreen> createState() => _PomodoroScreenState();
}

class _PomodoroScreenState extends State<PomodoroScreen> {
  Timer? _timer;
  int _remaining = 25 * 60;
  bool _running = false;
  // v2.10: three phases (mockup) instead of a focus/break toggle — every
  // 4th finished focus session earns a long break (see nextPomodoroPhase).
  PomodoroPhase _phase = PomodoroPhase.focus;
  int _focusCount = 0;
  String _subjectId = '';
  int _startedMs = 0;

  int get _phaseMinutes => pomodoroPhaseMinutes(
        _phase,
        focusMin: Settings.focusMin,
        breakMin: Settings.breakMin,
        longBreakMin: Settings.longBreakMin,
      );

  @override
  void initState() {
    super.initState();
    _remaining = Settings.focusMin * 60;
    _subjectId = widget.initialSubjectId;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _tick() {
    if (_remaining <= 1) {
      _finishPhase();
    } else {
      setState(() => _remaining--);
    }
  }

  Future<void> _finishPhase() async {
    _timer?.cancel();
    var next = _phase;
    if (_phase == PomodoroPhase.focus) {
      final id = newId();
      await DB.pomodoro.put(
        id,
        PomodoroSession(
          id: id,
          subjectId: _subjectId,
          startMs: _startedMs,
          focusMin: Settings.focusMin,
          breakMin: Settings.breakMin,
          completed: true,
        ),
      );
      if (mounted) showSnack(context, t('sessionSaved'));
      _focusCount++;
      next = nextPomodoroPhase(
          wasFocus: true, finishedFocusCount: _focusCount);
    } else {
      next = PomodoroPhase.focus;
    }
    setState(() {
      _phase = next;
      _running = false;
      _remaining = pomodoroPhaseMinutes(
            next,
            focusMin: Settings.focusMin,
            breakMin: Settings.breakMin,
            longBreakMin: Settings.longBreakMin,
          ) *
          60;
    });
  }

  void _startPause() {
    if (_running) {
      _timer?.cancel();
      setState(() => _running = false);
    } else {
      if (_remaining <= 0) {
        _remaining = _phaseMinutes * 60;
      }
      if (_startedMs == 0) {
        _startedMs = DateTime.now().millisecondsSinceEpoch;
      }
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
      setState(() => _running = true);
    }
  }

  void _reset() {
    _timer?.cancel();
    setState(() {
      _running = false;
      _startedMs = 0;
      _remaining = _phaseMinutes * 60;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mm = (_remaining ~/ 60).toString().padLeft(2, '0');
    final ss = (_remaining % 60).toString().padLeft(2, '0');
    final totalSec = _phaseMinutes * 60;
    final progress =
        totalSec > 0 ? 1 - _remaining / totalSec : 0.0;
    final phaseLabel = _phase == PomodoroPhase.focus
        ? t('focusPhase')
        : _phase == PomodoroPhase.shortBreak
            ? t('shortBreak')
            : t('longBreak');
    final ringColor = _phase == PomodoroPhase.focus
        ? AppColors.primary
        : _phase == PomodoroPhase.shortBreak
            ? AppColors.success
            : AppColors.secondary;

    return Scaffold(
      appBar: AppBar(title: Text(t('pomodoro'))),
      body: AuroraBackground(
        child: ValueListenableBuilder(
          valueListenable: DB.pomodoro.listenable(),
          builder: (_, __, ___) {
            final todayStart = dayStartMs(DateTime.now());
            final todayMin = DB.pomodoro.values
                .where((s) =>
                    s.startMs >= todayStart && s.completed)
                .fold<int>(0, (a, s) => a + s.focusMin);
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
              children: [
                GlassCard(
                  child: Column(
                    children: [
                      SegmentedButton<PomodoroPhase>(
                        // Compact text: three Arabic labels must fit a
                        // narrow phone without overflowing the segment row.
                        style: const ButtonStyle(
                          visualDensity: VisualDensity(
                              horizontal: -2, vertical: -2),
                          textStyle: WidgetStatePropertyAll(
                              TextStyle(fontSize: 12)),
                        ),
                        segments: [
                          ButtonSegment(
                              value: PomodoroPhase.focus,
                              label: Text(t('focusTime'))),
                          ButtonSegment(
                              value: PomodoroPhase.shortBreak,
                              label: Text(t('shortBreak'))),
                          ButtonSegment(
                              value: PomodoroPhase.longBreak,
                              label: Text(t('longBreak'))),
                        ],
                        selected: {_phase},
                        onSelectionChanged: (s) {
                          setState(() => _phase = s.first);
                          _reset();
                        },
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: 220,
                        height: 220,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 220,
                              height: 220,
                              child: CircularProgressIndicator(
                                value: progress.clamp(0.0, 1.0),
                                strokeWidth: 14,
                                backgroundColor: AppColors.primary
                                    .withValues(alpha: 0.12),
                                color: ringColor,
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('$mm:$ss',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 48)),
                                // v2.10: the phase is labelled, not just a
                                // number — focus / short break / long break.
                                Text(phaseLabel,
                                    style: TextStyle(
                                        color: ringColor,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14)),
                                Text('$_focusCount / 4',
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                        fontSize: 12)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      LabeledDropdown<String>(
                        value: _subjectId.isEmpty ? null : _subjectId,
                        items: [
                          DropdownMenuItem(value: '', child: Text('—')),
                          for (final s in DB.subjects.values)
                            DropdownMenuItem(
                                value: s.id, child: Text(s.name)),
                        ],
                        onChanged: _running
                            ? null
                            : (v) =>
                                setState(() => _subjectId = v ?? ''),
                        label: t('subject'),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [
                          GlassButton(
                            label: _running
                                ? t('pause')
                                : (_remaining < _phaseMinutes * 60 &&
                                        _remaining > 0
                                    ? t('resume')
                                    : t('start')),
                            icon: _running
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            onPressed: _startPause,
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            icon: const Icon(
                                Icons.refresh_rounded),
                            onPressed: _reset,
                            tooltip: t('reset'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SectionHeader(title: t('todayStats')),
                Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        icon: Icons.timer_rounded,
                        value: formatMinutes(todayMin),
                        label: t('focusTime'),
                        gradient: const [
                          AppColors.primary,
                          AppColors.secondary
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatCard(
                        icon: Icons.done_all_rounded,
                        value:
                            '${DB.pomodoro.values.where((s) => s.startMs >= todayStart && s.completed).length}',
                        label: t('done'),
                        gradient: const [
                          AppColors.success,
                          AppColors.secondary
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
