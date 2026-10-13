import 'package:flutter_test/flutter_test.dart';
import 'package:study_assistant/core/logic.dart';

void main() {
  group('GPA', () {
    test('weighted average on 4.0 scale', () {
      // 95% (4.0) x3h + 75% (3.0) x3h => 3.5
      final gpa = gpaFromPercents([
        (pct: 95, ch: 3),
        (pct: 75, ch: 3),
      ]);
      expect(gpa, closeTo(3.5, 0.001));
    });

    test('credit-hour weighting', () {
      // 95% (4.0) x6h + 50% (1.0) x2h => (24+2)/8 = 3.25
      final gpa = gpaFromPercents([
        (pct: 95, ch: 6),
        (pct: 50, ch: 2),
      ]);
      expect(gpa, closeTo(3.25, 0.001));
    });

    test('empty list => 0', () {
      expect(gpaFromPercents([]), 0);
    });

    test('failing grade => 0 points', () {
      expect(gpaFromPercents([(pct: 30, ch: 3)]), 0);
    });
  });

  group('attendance', () {
    test('percentage', () {
      expect(attendancePct(3, 4), 75.0);
      expect(attendancePct(0, 0), 0);
      expect(attendancePct(5, 5), 100.0);
    });
  });

  group('spaced repetition (SM-2 lite)', () {
    test('unknown card resets to 1 day', () {
      final r = sm2Update(
          interval: 10, ease: 2.5, reviews: 3, known: false, nowMs: 1000);
      expect(r.interval, 1);
      expect(r.ease, lessThan(2.5));
      expect(r.nextMs, 1000 + 86400000);
    });

    test('first known review => 1 day, ease up', () {
      final r = sm2Update(
          interval: 1, ease: 2.5, reviews: 0, known: true, nowMs: 0);
      expect(r.interval, 1);
      expect(r.ease, closeTo(2.6, 0.001));
    });

    test('second known review => 6 days', () {
      final r = sm2Update(
          interval: 1, ease: 2.5, reviews: 1, known: true, nowMs: 0);
      expect(r.interval, 6);
    });

    test('later reviews grow by ease factor', () {
      final r = sm2Update(
          interval: 6, ease: 2.5, reviews: 2, known: true, nowMs: 0);
      expect(r.interval, closeTo(15.6, 0.01));
    });

    test('ease clamped to minimum 1.3', () {
      final r = sm2Update(
          interval: 5, ease: 1.35, reviews: 4, known: false, nowMs: 0);
      expect(r.ease, 1.3);
    });
  });

  group('exam grading', () {
    final qs = [
      QuizQ(
          q: 'Q1',
          type: 'mcq',
          options: ['a', 'b'],
          answer: 'b',
          explanation: ''),
      QuizQ(q: 'Q2', type: 'tf', options: ['true', 'false'], answer: 'true'),
      QuizQ(q: 'Q3', type: 'short', answer: ''),
    ];

    test('objective questions graded, short left ungraded', () {
      final g = gradeExam(qs, {0: 'b', 1: 'false', 2: 'some essay'});
      expect(g.score, 1);
      expect(g.maxScore, 3);
      expect(g.correct, [true, false, false]);
    });

    test('case-insensitive + trimmed matching', () {
      final g = gradeExam(qs, {0: '  B ', 1: 'TRUE'});
      expect(g.correct, [true, true, false]);
    });

    test('missing answers count as wrong', () {
      final g = gradeExam(qs, {});
      expect(g.score, 0);
    });
  });

  group('question JSON parsing', () {
    test('extracts array from chatty output', () {
      const raw =
          'Here you go:\n[{"q":"Q?","type":"mcq","options":["a","b"],"answer":"a","explanation":"e"}]\nDone.';
      final qs = parseQuestions(raw);
      expect(qs.length, 1);
      expect(qs.first.q, 'Q?');
      expect(qs.first.answer, 'a');
      expect(qs.first.options, ['a', 'b']);
    });
  });

  group('timetable overlap', () {
    test('detects overlap', () {
      final existing = [(start: 540, end: 630, id: 'a')];
      expect(hasOverlap(existing, 1, 600, 660), true);
      expect(hasOverlap(existing, 1, 630, 700), false); // touching is OK
      expect(hasOverlap(existing, 1, 500, 540), false);
      expect(hasOverlap(existing, 1, 600, 660, excludeId: 'a'), false);
    });
  });

  group('countdown text', () {
    String tr(String k) => {'daysLeft': 'left', 'days': 'days'}[k] ?? k;
    test('days / overdue', () {
      expect(countdownParts(3 * 86400000, 0, tr), contains('3'));
      expect(countdownParts(0, 1000, tr), 'overdue');
    });
  });
}
