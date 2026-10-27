import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_assistant/core/grok_glass.dart';
import 'package:study_assistant/core/l10n.dart';
import 'package:study_assistant/core/theme.dart';
import 'package:study_assistant/core/widgets.dart';

void main() {
  testWidgets('v2.10: GlassCard blur sits inside a RepaintBoundary',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: GlassCard(child: Text('card'))),
      ),
    );
    final blur = find.byType(BackdropFilter);
    expect(blur, findsOneWidget);
    expect(
      find.ancestor(of: blur, matching: find.byType(RepaintBoundary)),
      findsWidgets,
    );
  });

  testWidgets('v2.10: DelayedElasticReveal delay actually delays',
      (tester) async {
    Widget build({required Duration delay}) => MaterialApp(
          home: Scaffold(
            body: DelayedElasticReveal(
              visible: true,
              delay: delay,
              child: const Text('revealed'),
            ),
          ),
        );
    // Zero delay: visible after the elastic animation settles.
    await tester.pumpWidget(build(delay: Duration.zero));
    await tester.pumpAndSettle();
    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
      1.0,
    );
    // 2s delay: still hidden before the delay elapses.
    await tester.pumpWidget(build(delay: const Duration(seconds: 2)));
    await tester.pump();
    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
      0.0,
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
      1.0,
    );
  });

  testWidgets('v2.10: suggested-prompt chips call back with the prompt',
      (tester) async {
    String? received;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SuggestedPromptsRow(
            prompts: const [
              (label: 'Explain', prompt: 'Explain: topic'),
              (label: 'Debug', prompt: 'Debug: code'),
            ],
            onSuggestedPrompt: (p) => received = p,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Debug'));
    expect(received, 'Debug: code');
  });

  testWidgets('v2.10: NextLectureCard + RoomChip render typed data',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              NextLectureCard(
                title: 'Data Structures',
                kindLabel: 'Lecture',
                timeLabel: '10:30 - 12:00',
                place: 'Hall 204',
                statusText: 'in 45 min',
                onTap: () {},
              ),
              const RoomChip(room: '204'),
            ],
          ),
        ),
      ),
    );
    expect(find.text('Data Structures'), findsOneWidget);
    expect(find.text('in 45 min'), findsOneWidget);
    expect(find.text('Hall 204'), findsOneWidget);
    expect(find.text('204'), findsOneWidget);
  });

  test('v2.10: pomodoro phases — long break every 4th focus session', () {
    expect(
      nextPomodoroPhase(wasFocus: true, finishedFocusCount: 1),
      PomodoroPhase.shortBreak,
    );
    expect(
      nextPomodoroPhase(wasFocus: true, finishedFocusCount: 3),
      PomodoroPhase.shortBreak,
    );
    expect(
      nextPomodoroPhase(wasFocus: true, finishedFocusCount: 4),
      PomodoroPhase.longBreak,
    );
    expect(
      nextPomodoroPhase(wasFocus: true, finishedFocusCount: 8),
      PomodoroPhase.longBreak,
    );
    expect(
      nextPomodoroPhase(wasFocus: false, finishedFocusCount: 4),
      PomodoroPhase.focus,
    );
    expect(
      pomodoroPhaseMinutes(PomodoroPhase.focus,
          focusMin: 25, breakMin: 5, longBreakMin: 15),
      25,
    );
    expect(
      pomodoroPhaseMinutes(PomodoroPhase.shortBreak,
          focusMin: 25, breakMin: 5, longBreakMin: 15),
      5,
    );
    expect(
      pomodoroPhaseMinutes(PomodoroPhase.longBreak,
          focusMin: 25, breakMin: 5, longBreakMin: 15),
      15,
    );
  });

  testWidgets('v2.10: delete confirmation gates on No (cancel returns false)',
      (tester) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => TextButton(
              onPressed: () async {
                result = await confirmDelete(ctx);
              },
              child: const Text('delete me'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('delete me'));
    await tester.pumpAndSettle();
    expect(find.text(t('confirmDelete')), findsOneWidget);
    await tester.tap(find.text(t('no')));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });

  test('v2.10: no lib source file contains the forbidden class word', () {
    final dir = Directory('lib');
    expect(dir.existsSync(), isTrue);
    final bad = <String>[];
    for (final f in dir.listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final src = f.readAsStringSync();
      if (src.contains('حصص') || src.contains('حصة')) bad.add(f.path);
    }
    expect(bad, isEmpty, reason: 'files containing the word: $bad');
  });

  testWidgets('v2.10: NextLectureCard does not overflow a narrow phone',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NextLectureCard(
            title: 'Data Structures and Algorithms — a very long title',
            kindLabel: 'Lecture',
            timeLabel: '10:30 - 12:00',
            place: 'Room 302, Engineering Block, Building A',
            statusText: 'in 45 min',
            onTap: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Data Structures and Algorithms — a very long title'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('v2.10: new phase labels exist in both languages', () {
    L.lang.value = 'ar';
    expect(L.t('longBreak'), 'استراحة طويلة');
    expect(L.t('shortBreak'), 'استراحة قصيرة');
    expect(L.t('focusPhase'), 'جلسة تركيز');
    L.lang.value = 'en';
    expect(L.t('longBreak'), 'Long break');
    expect(L.t('shortBreak'), 'Short break');
    expect(L.t('focusPhase'), 'Focus session');
  });
}
