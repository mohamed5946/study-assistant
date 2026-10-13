import 'package:flutter_test/flutter_test.dart';
import 'package:study_assistant/core/logic.dart';
import 'package:study_assistant/core/schedule_optimizer.dart';

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

  group('timetable import parsing', () {
    test('parseWeekday', () {
      expect(parseWeekday('Mon'), 1);
      expect(parseWeekday('friday'), 5);
      expect(parseWeekday('Sun'), 7);
      expect(parseWeekday('xyz'), 0);
    });

    test('parseClock', () {
      expect(parseClock('10:30'), 630);
      expect(parseClock('9:05 AM'), 545);
      expect(parseClock('2:30 PM'), 870);
      expect(parseClock('bad'), -1);
    });

    test('ImportedSession.fromJson + valid', () {
      final s = ImportedSession.fromJson({
        'subject': 'Data Structures',
        'code': 'CS201',
        'day': 'Tue',
        'start': '10:00',
        'end': '11:30',
        'place': 'Bldg A',
        'instructor': 'Dr X',
        'kind': 'lecture',
        'group': '',
      });
      expect(s.valid, true);
      expect(s.weekday, 2);
      expect(s.startMin, 600);
      final bad = ImportedSession.fromJson({'subject': '', 'day': 'Tue', 'start': '10:00', 'end': '09:00'});
      expect(bad.valid, false);
    });
  });

  group('session overlap', () {
    ImportedSession s(String subj, int day, int start, int end) =>
        ImportedSession(subject: subj, weekday: day, startMin: start, endMin: end);

    test('overlap detection', () {
      expect(sessionsOverlap(s('A', 1, 600, 660), s('B', 1, 630, 700)), true);
      expect(sessionsOverlap(s('A', 1, 600, 660), s('B', 1, 660, 720)), false);
      expect(sessionsOverlap(s('A', 1, 600, 660), s('B', 2, 630, 700)), false);
      expect(hasAnyOverlap([s('A', 1, 600, 660), s('B', 1, 630, 700)]), true);
      expect(hasAnyOverlap([s('A', 1, 600, 660), s('B', 1, 660, 720)]), false);
    });

    test('distinctDays', () {
      expect(distinctDays([s('A', 1, 600, 660), s('B', 1, 700, 760), s('C', 3, 600, 660)]), 2);
    });
  });

  group('schedule optimizer', () {
    ImportedSession s(String subj, String group, int day, int start, int end) =>
        ImportedSession(subject: subj, group: group, weekday: day, startMin: start, endMin: end);

    test('minimizes distinct days across section choices', () {
      // Math: group A on Mon 10-12, group B on Wed 10-12.
      // Physics: group A on Mon 13-15, group B on Thu 10-12.
      // Best: Math A + Physics A => 1 day (Mon). Any other combo => 2 days.
      final sessions = [
        s('Math', 'A', 1, 600, 720),
        s('Math', 'B', 3, 600, 720),
        s('Physics', 'A', 1, 780, 900),
        s('Physics', 'B', 4, 600, 720),
      ];
      final built = buildOptions(sessions);
      final res = optimizeSchedule(built.options, built.labels);
      expect(res, isNotNull);
      expect(res!.days, 1);
      expect(res.groups['Math'], 'A');
      expect(res.groups['Physics'], 'A');
    });

    test('returns null + clash pairs when impossible', () {
      // Two subjects, single fixed slot each, overlapping.
      final sessions = [
        s('Math', '', 1, 600, 720),
        s('Physics', '', 1, 660, 780),
      ];
      final built = buildOptions(sessions);
      final res = optimizeSchedule(built.options, built.labels);
      expect(res, isNull);
      final clashes = findClashingSubjects(sessions);
      expect(clashes.length, 1);
      expect(clashes.first.$1, 'Math');
      expect(clashes.first.$2, 'Physics');
    });

    test('shared lectures join every group', () {
      // Chem lecture (no group) Mon 9-10 + lab A Tue 10-12 / lab B Wed 10-12.
      final sessions = [
        s('Chem', '', 1, 540, 600),
        s('Chem', 'A', 2, 600, 720),
        s('Chem', 'B', 3, 600, 720),
      ];
      final built = buildOptions(sessions);
      expect(built.options['Chem']!.length, 2);
      // each option contains the shared lecture
      for (final opt in built.options['Chem']!) {
        expect(opt.any((x) => x.startMin == 540), true);
      }
    });
  });

  group('self-test scoring', () {
    test('counts correct answers', () {
      final r = scoreSelfTest(
        ['Paris', 'true', '42'],
        {0: 'paris', 1: 'false', 2: ''},
      );
      expect(r.correct, 1);
      expect(r.total, 3);
    });
  });

  group('page citations', () {
    test('extracts [p:N] markers', () {
      final pages = extractPageCitations('Photosynthesis happens here [p:12] and there [p:12] too [p:3].');
      expect(pages, [3, 12]);
      expect(stripPageCitations('See this [p:5] now'), 'See this now');
    });
  });

  group('grade average', () {
    test('percentage average across entries', () {
      expect(gradeAverage([(80, 100), (45, 50)]), closeTo(85, 0.001));
      expect(gradeAverage([]), 0);
      expect(gradeAverage([(10, 0)]), 0); // invalid max skipped
    });
  });
}
