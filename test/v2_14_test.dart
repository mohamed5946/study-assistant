import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_assistant/core/bin_delete.dart';
import 'package:study_assistant/core/chat_aurora.dart';
import 'package:study_assistant/core/l10n.dart';
import 'package:study_assistant/core/models.dart';
import 'package:study_assistant/core/store.dart';

/// v2.14: animated AI-chat aurora + message entry + typing dots, and
/// the "bin eats the label" delete animation (wired through the shared
/// confirmDelete dialog's Yes button).
void main() {
  late Directory tmp;

  setUpAll(() async {
    tmp = await Directory.systemTemp.createTemp('sa_v214_test');
    Hive.init(tmp.path);
    registerAdapters();
    DB.kv = await Hive.openBox('kv');
  });

  tearDownAll(() async {
    await Hive.close();
    await tmp.delete(recursive: true);
  });

  setUp(() async {
    await DB.kv.clear();
  });

  Widget wrap(Widget child) => MaterialApp(
        home: Scaffold(body: Center(child: child)),
      );

  testWidgets('animated aurora renders its child and keeps ticking',
      (tester) async {
    await tester.pumpWidget(wrap(AnimatedAuroraBackground(
      child: const Text('chat body'),
    )));
    expect(find.text('chat body'), findsOneWidget);
    // Advance the drift without settling (the controller repeats).
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('chat body'), findsOneWidget);
    // Leaving the screen disposes the controller: no crash on rebuild.
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    expect(find.text('chat body'), findsNothing);
  });

  testWidgets('animated aurora is fully static under reduce-animation',
      (tester) async {
    // Hive writes inside a testWidgets body must run under runAsync
    // (real I/O); an unawaited put otherwise strands the next test's
    // setUp clear behind a write the fake clock never delivers.
    await tester.runAsync(() => DB.kv.put('reduceAnim', true));
    await tester.pumpWidget(wrap(AnimatedAuroraBackground(
      child: const Text('chat body'),
    )));
    expect(find.text('chat body'), findsOneWidget);
    // No repeating controller: pumpAndSettle must terminate.
    await tester.pumpAndSettle();
    expect(find.text('chat body'), findsOneWidget);
  });

  testWidgets('message entry fades + slides in once, then stays opaque',
      (tester) async {
    await tester.pumpWidget(wrap(const ChatMessageEntry(
      animate: true,
      child: Text('hello'),
    )));
    // First frame: fully transparent.
    final first = tester.widget<Opacity>(find.byType(Opacity).first);
    expect(first.opacity, 0.0);
    await tester.pump(const Duration(milliseconds: 400));
    final last = tester.widget<Opacity>(find.byType(Opacity).first);
    expect(last.opacity, 1.0);
  });

  testWidgets('message entry with animate=false renders instantly',
      (tester) async {
    await tester.pumpWidget(wrap(const ChatMessageEntry(
      animate: false,
      child: Text('hello'),
    )));
    expect(find.text('hello'), findsOneWidget);
    expect(find.byType(Opacity), findsNothing);
  });

  testWidgets('typing dots render three bouncing dots', (tester) async {
    await tester.pumpWidget(wrap(const TypingDots()));
    // Exactly the three dots' Opacity widgets, nothing else.
    expect(find.byType(Opacity), findsNWidgets(3));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(Opacity), findsNWidgets(3));
  });

  testWidgets('bin button: autoStart eats the label then completes',
      (tester) async {
    var completed = false;
    await tester.pumpWidget(wrap(BinDeleteButton(
      label: 'Delete',
      autoStart: true,
      onComplete: () => completed = true,
    )));
    // Label letters present at rest.
    expect(find.text('D'), findsOneWidget);
    expect(find.text('e'), findsWidgets);
    // Not complete immediately after starting.
    await tester.pump(const Duration(milliseconds: 100));
    expect(completed, isFalse);
    // Past the 1s animation: pump the elapsed time, then one more
    // frame at the advanced time (pump(duration) runs its frame at
    // the previous fake time, so the completion frame needs the extra
    // pump) — then the pill has shrunk to a circle and completion
    // has fired.
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pump();
    expect(completed, isTrue);
    expect(find.text('D'), findsNothing);
  });

  testWidgets('bin button: tap starts the animation', (tester) async {
    var completed = false;
    await tester.pumpWidget(wrap(BinDeleteButton(
      label: 'Delete',
      onComplete: () => completed = true,
    )));
    expect(completed, isFalse);
    await tester.tap(find.byType(BinDeleteButton));
    expect(completed, isFalse);
    // Drive the animation with real frames (pumpAndSettle), which is
    // what a device does; a single pump(duration) after a tap does
    // not advance this ticker in the test harness.
    await tester.pumpAndSettle(const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
    expect(completed, isTrue);
    expect(find.text('D'), findsNothing);
  });

  testWidgets('bin button: reduce-animation skips straight to complete',
      (tester) async {
    await tester.runAsync(() => DB.kv.put('reduceAnim', true));
    var completed = false;
    await tester.pumpWidget(wrap(BinDeleteButton(
      label: 'Delete',
      autoStart: true,
      onComplete: () => completed = true,
    )));
    await tester.pump(const Duration(milliseconds: 100));
    expect(completed, isTrue);
  });

  testWidgets('confirm Yes button animates then confirms', (tester) async {
    L.lang.value = 'en';
    var confirmed = false;
    await tester.pumpWidget(wrap(AnimatedConfirmYesButton(
      onConfirmed: () => confirmed = true,
    )));
    expect(find.text(t('yes')), findsOneWidget);
    await tester.tap(find.text(t('yes')));
    await tester.pump();
    // Yes swapped for the bin pill eating the delete label.
    expect(find.text('D'), findsOneWidget);
    expect(confirmed, isFalse);
    await tester.pumpAndSettle(const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
    expect(confirmed, isTrue);
    L.lang.value = 'ar';
  });
}
