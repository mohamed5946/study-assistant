import 'package:flutter_test/flutter_test.dart';
import 'package:study_assistant/core/logic.dart';

void main() {
  group('v2.3 GPA fixes', () {
    test('multi-assessment subject weighted once (not 2.50 bug)', () {
      // Subject with 2 assessments (95, 85) x 3h: avg 90 => 4.0 on scale.
      // Old code weighted each assessment by 3h separately, over-counting
      // multi-assessment subjects.
      final gpa = totalGpaFromRecords([
        (subjectId: 's1', pct: 95, ch: 3),
        (subjectId: 's1', pct: 85, ch: 3),
      ]);
      expect(gpa, closeTo(4.0, 0.01));
    });

    test('two subjects with different assessment counts', () {
      // s1: [100] x 3h => 4.0; s2: [80, 80, 80] avg 80 x 3h => 3.3
      // => (4.0*3 + 3.3*3)/6 = 3.65
      final gpa = totalGpaFromRecords([
        (subjectId: 's1', pct: 100, ch: 3),
        (subjectId: 's2', pct: 80, ch: 3),
        (subjectId: 's2', pct: 80, ch: 3),
        (subjectId: 's2', pct: 80, ch: 3),
      ]);
      expect(gpa, closeTo(3.65, 0.01));
    });

    test('subjectGpaFromPercents averages assessments then converts', () {
      // [60, 100] avg 80 => 3.3
      expect(subjectGpaFromPercents([60, 100], 3), closeTo(3.3, 0.01));
    });

    test('empty records => 0', () {
      expect(totalGpaFromRecords([]), 0);
      expect(subjectGpaFromPercents([], 3), 0);
    });
  });
}
