import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_assistant/core/grok_glass.dart';
import 'package:study_assistant/core/l10n.dart';

void main() {
  testWidgets('v2.11: mockup timeline row renders time, title, room chip',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TimelineClassRow(
            startLabel: '10:30',
            endLabel: '12:00',
            title: 'Data Structures',
            subtitle: 'Hall 204',
            room: '204',
            color: Colors.blue,
            onTap: () {},
          ),
        ),
      ),
    );
    expect(find.text('Data Structures'), findsOneWidget);
    expect(find.text('10:30'), findsOneWidget);
    expect(find.text('204'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('v2.11: timeline row does not overflow a narrow phone',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TimelineClassRow(
            startLabel: '10:30',
            endLabel: '12:00',
            title: 'A very long subject title that must wrap, not overflow',
            subtitle: 'Room 302, Engineering Block, Building A',
            room: 'Room 302, Engineering Block',
            color: Colors.blue,
            onTap: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  test('v2.11: week helpers are Sunday-first with consecutive dates', () {
    // 2026-10-27 is a Tuesday.
    final days = weekDaysSundayFirst(DateTime(2026, 10, 27));
    expect(days.map((d) => d.weekday).toList(),
        [7, 1, 2, 3, 4, 5, 6]);
    expect(weekSunday(DateTime(2026, 10, 27)),
        DateTime(2026, 10, 25));
    for (var i = 1; i < days.length; i++) {
      expect(days[i].date.difference(days[i - 1].date),
          const Duration(days: 1));
    }
    expect(days.first.date.weekday, 7);
  });

  test('v2.11: prompt-set refresh cycles through all sets', () {
    expect(nextPromptSetIndex(0, 3), 1);
    expect(nextPromptSetIndex(1, 3), 2);
    expect(nextPromptSetIndex(2, 3), 0);
    expect(nextPromptSetIndex(0, 0), 0);
  });

  testWidgets('v2.11: duration chip renders and calls back',
      (tester) async {
    L.lang.value = 'en';
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DurationChip(
            label: 'Focus',
            minutes: 25,
            selected: true,
            onTap: () => tapped = true,
          ),
        ),
      ),
    );
    expect(find.text('25 min'), findsOneWidget);
    await tester.tap(find.text('Focus'));
    expect(tapped, isTrue);
  });

  testWidgets('v2.11: mockup ring renders with centered time',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MockupRing(
            progress: 0.4,
            size: 260,
            color: Colors.blue,
            child: const Text('25:00'),
          ),
        ),
      ),
    );
    expect(find.text('25:00'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  test('v2.11: new mockup labels exist in both languages', () {
    L.lang.value = 'ar';
    expect(L.t('todaysLectures'), 'محاضرات اليوم');
    expect(L.t('summarizeTopic'), 'لخّص الموضوع');
    expect(L.t('practiceQuestions'), 'اديني أسئلة تدريب');
    expect(L.t('explainWithDiagram'), 'اشرح بمخطط');
    expect(L.t('suggestedPrompts'), 'اقتراحات جاهزة');
    expect(L.t('refreshPrompts'), 'تحديث');
    expect(L.t('pomodoroTip'), 'الاستراحات القصيرة بتحسّن التثبيت.');
    expect(L.t('todaysGoal'), 'هدف النهاردة');
    expect(L.t('weekOf'), 'الأسبوع');
    expect(L.t('restDay'), 'يوم راحة');
    expect(L.t('ocrScan'), 'مسح OCR');
    expect(L.t('generateExam'), 'توليد امتحان');
    expect(L.t('mindMapSection'), 'خريطة ذهنية تفاعلية');
    L.lang.value = 'en';
    expect(L.t('todaysLectures'), "Today's lectures");
    expect(L.t('summarizeTopic'), 'Summarize this topic');
    expect(L.t('practiceQuestions'), 'Give me practice questions');
    expect(L.t('explainWithDiagram'), 'Explain with diagram');
    expect(L.t('suggestedPrompts'), 'Suggested prompts');
    expect(L.t('refreshPrompts'), 'Refresh');
    expect(L.t('pomodoroTip'), 'Short breaks improve retention.');
    expect(L.t('todaysGoal'), "Today's goal");
    expect(L.t('weekOf'), 'Week');
    expect(L.t('restDay'), 'Rest day');
    expect(L.t('ocrScan'), 'OCR Scan');
    expect(L.t('generateExam'), 'Generate Exam');
    expect(L.t('mindMapSection'), 'Interactive Mind Map');
  });
}
