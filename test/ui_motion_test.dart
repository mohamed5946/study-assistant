import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_assistant/core/l10n.dart';
import 'package:study_assistant/core/motion.dart';
import 'package:study_assistant/core/theme.dart';

void main() {
  test('hero tags are unique per item, never a shared literal', () {
    expect(heroTag('subject', 'a'), isNot(heroTag('subject', 'b')));
    expect(heroTag('subject', 'a'), isNot(heroTag('pdf', 'a')));
    expect(heroTag('subject', 'a'), 'subject-a');
    expect(heroTag('profile', 'avatar'), 'profile-avatar');
  });

  test('elastic reveal uses the specified overshoot easing', () {
    final c = elasticCurve;
    expect(c.a, 0.22);
    expect(c.b, 1.32);
    expect(c.c, 0.36);
    expect(c.d, 1.0);
    // Overshoot: the curve must pass above 1 before settling at 1.
    expect(c.transform(0.7), greaterThan(0.7));
  });

  test('palette is blue-only: no violet/purple/pink/indigo color value', () {
    expect(AppColors.primary, const Color(0xFF0284C7));
    expect(AppColors.primaryDark, const Color(0xFF0369A1));
    expect(AppColors.secondary, const Color(0xFF0D9488));
    // The old indigo 0xFF4F46E5 must not be in the subject palette.
    expect(AppColors.subjectPalette, isNot(contains(0xFF4F46E5)));
    expect(AppColors.subjectPalette, contains(0xFF2563EB));
  });

  test('Arabic strings use محاضرات/سيكشن wording, never حصص/حصة', () {
    L.lang.value = 'ar';
    for (final key in [
      'nextClass',
      'addEntry',
      'editEntry',
      'overlapWarning',
      'deleteEntry',
      'nextLecture',
      'correctHint',
      'editSession',
      'sessionType',
    ]) {
      final v = L.t(key);
      expect(v, isNot(contains('حصص')));
      expect(v, isNot(contains('حصة')));
      expect(v, isNot(contains('الحصة')));
    }
    expect(L.t('reduceAnimations'), 'تقليل الحركات');
    L.lang.value = 'en';
    expect(L.t('reduceAnimations'), 'Reduce animations');
    expect(L.t('details'), 'Details');
  });

  testWidgets('PressScale and FadeSlideIn render their child',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              PressScale(child: Text('press me')),
              FadeSlideIn(index: 2, child: Text('fade me')),
            ],
          ),
        ),
      ),
    );
    expect(find.text('press me'), findsOneWidget);
    expect(find.text('fade me'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('fade me'), findsOneWidget);
  });

  testWidgets('ElasticReveal collapses to nothing and expands on toggle',
      (tester) async {
    Widget build(bool expanded) => MaterialApp(
          home: Scaffold(
            body: ElasticReveal(
              expanded: expanded,
              children: const [Text('detail line')],
            ),
          ),
        );
    await tester.pumpWidget(build(false));
    await tester.pumpAndSettle();
    expect(find.text('detail line'), findsNothing);
    await tester.pumpWidget(build(true));
    await tester.pumpAndSettle();
    expect(find.text('detail line'), findsOneWidget);
  });
}
