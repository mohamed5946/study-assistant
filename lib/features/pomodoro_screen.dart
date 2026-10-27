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
  bool _showTip = true;
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

  Future<void> _editDurations() async {
    final fC = TextEditingController(text: '${Settings.focusMin}');
    final bC = TextEditingController(text: '${Settings.breakMin}');
    final lC = TextEditingController(text: '${Settings.longBreakMin}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('editDurations')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: fC,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: t('focusMin'))),
            const SizedBox(height: 10),
            TextField(
                controller: bC,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: t('breakMin'))),
            const SizedBox(height: 10),
            TextField(
                controller: lC,
                keyboardType: TextInputType.number,
                decoration:
                    InputDecoration(labelText: t('longBreakMin'))),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(t('cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(t('save'))),
        ],
      ),
    );
    if (ok == true) {
      final f = int.tryParse(fC.text);
      final b = int.tryParse(bC.text);
      final l = int.tryParse(lC.text);
      if (f != null && f > 0) Settings.focusMin = f;
      if (b != null && b > 0) Settings.breakMin = b;
      if (l != null && l > 0) Settings.longBreakMin = l;
      _reset();
      if (mounted) setState(() {});
    }
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
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: ringColor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: ringColor),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _phase == PomodoroPhase.focus
                                  ? 'FOCUS'
                                  : phaseLabel.toUpperCase(),
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                  color: ringColor),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: 260,
                        height: 260,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 260,
                              height: 260,
                              child: CircularProgressIndicator(
                                value: progress.clamp(0.0, 1.0),
                                strokeWidth: 16,
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
                                        fontSize: 56)),
                                // v2.10: the phase is labelled, not just a
                                // number — focus / short break / long break.
                                Text(phaseLabel,
                                    style: TextStyle(
                                        color: ringColor,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14)),
                                Text(
                                    '${t('todaysGoal')} • $_focusCount / 4',
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
                          Expanded(
                            child: GlassButton(
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
                const SizedBox(height: 16),
                // Mockup duration chips (tap switches phase) + edit.
                Row(
                  children: [
                    Expanded(
                      child: DurationChip(
                        label: t('focusTime'),
                        minutes: Settings.focusMin,
                        selected: _phase == PomodoroPhase.focus,
                        onTap: () {
                          setState(() => _phase = PomodoroPhase.focus);
                          _reset();
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DurationChip(
                        label: t('shortBreak'),
                        minutes: Settings.breakMin,
                        selected: _phase == PomodoroPhase.shortBreak,
                        onTap: () {
                          setState(
                              () => _phase = PomodoroPhase.shortBreak);
                          _reset();
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DurationChip(
                        label: t('longBreak'),
                        minutes: Settings.longBreakMin,
                        selected: _phase == PomodoroPhase.longBreak,
                        onTap: () {
                          setState(
                              () => _phase = PomodoroPhase.longBreak);
                          _reset();
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_rounded, size: 20),
                      tooltip: t('editDurations'),
                      onPressed: _editDurations,
                    ),
                  ],
                ),
                if (_showTip) ...[
                  const SizedBox(height: 14),
                  GlassCard(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color:
                                AppColors.warning.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.lightbulb_rounded,
                              color: AppColors.warning),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(t('pomodoroTip'),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () =>
                              setState(() => _showTip = false),
                        ),
                      ],
                    ),
                  ),
                ],
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
