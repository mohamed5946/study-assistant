import 'dart:async';
import 'package:flutter/material.dart';
import '../core/l10n.dart';
import '../core/models.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../core/widgets.dart';

class PomodoroScreen extends StatefulWidget {
  const PomodoroScreen({super.key});
  @override
  State<PomodoroScreen> createState() => _PomodoroScreenState();
}

class _PomodoroScreenState extends State<PomodoroScreen> {
  Timer? _timer;
  int _remaining = 25 * 60;
  bool _running = false;
  bool _isBreak = false;
  String _subjectId = '';
  int _startedMs = 0;

  @override
  void initState() {
    super.initState();
    _remaining = Settings.focusMin * 60;
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
    if (!_isBreak) {
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
    }
    setState(() {
      _isBreak = !_isBreak;
      _running = false;
      _remaining =
          (_isBreak ? Settings.breakMin : Settings.focusMin) * 60;
    });
  }

  void _startPause() {
    if (_running) {
      _timer?.cancel();
      setState(() => _running = false);
    } else {
      if (_remaining <= 0) {
        _remaining =
            (_isBreak ? Settings.breakMin : Settings.focusMin) * 60;
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
      _remaining =
          (_isBreak ? Settings.breakMin : Settings.focusMin) * 60;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mm = (_remaining ~/ 60).toString().padLeft(2, '0');
    final ss = (_remaining % 60).toString().padLeft(2, '0');
    final totalSec =
        (_isBreak ? Settings.breakMin : Settings.focusMin) * 60;
    final progress =
        totalSec > 0 ? 1 - _remaining / totalSec : 0.0;

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
                      SegmentedButton<bool>(
                        segments: [
                          ButtonSegment(
                              value: false,
                              label: Text(t('focusTime'))),
                          ButtonSegment(
                              value: true,
                              label: Text(t('breakTime'))),
                        ],
                        selected: {_isBreak},
                        onSelectionChanged: (s) {
                          _reset();
                          setState(() => _isBreak = s.first);
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
                                color: _isBreak
                                    ? AppColors.success
                                    : AppColors.primary,
                              ),
                            ),
                            Text('$mm:$ss',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 48)),
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
                                : (_remaining <
                                            (_isBreak
                                                    ? Settings.breakMin
                                                    : Settings.focusMin) *
                                                60 &&
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
