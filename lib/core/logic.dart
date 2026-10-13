import 'dart:convert';
import 'dart:math';

/// Pure business logic for Study Assistant — no Flutter dependencies,
/// covered by unit tests.

/// GPA on a 4.0 scale from percentage, weighted by credit hours.
/// [grades]: list of (percent 0-100, creditHours).
double gpaFromPercents(List<({double pct, double ch})> grades) {
  double pts = 0, ch = 0;
  for (final g in grades) {
    pts += _pctToGpa(g.pct) * g.ch;
    ch += g.ch;
  }
  if (ch <= 0) return 0;
  return pts / ch;
}

double _pctToGpa(double pct) {
  if (pct >= 90) return 4.0;
  if (pct >= 85) return 3.7;
  if (pct >= 80) return 3.3;
  if (pct >= 75) return 3.0;
  if (pct >= 70) return 2.7;
  if (pct >= 65) return 2.3;
  if (pct >= 60) return 2.0;
  if (pct >= 55) return 1.7;
  if (pct >= 50) return 1.0;
  return 0.0;
}

/// Attendance percentage from present/total counts.
double attendancePct(int present, int total) =>
    total <= 0 ? 0 : (present / total) * 100;

/// SM-2-lite spaced repetition update.
/// Returns (newIntervalDays, newEase, nextReviewMs).
({double interval, double ease, int nextMs}) sm2Update({
  required double interval,
  required double ease,
  required int reviews,
  required bool known,
  required int nowMs,
}) {
  double e = ease + (known ? 0.1 : -0.25);
  e = e.clamp(1.3, 2.8);
  double nextInterval;
  if (!known) {
    nextInterval = 1;
  } else if (reviews == 0) {
    nextInterval = 1;
  } else if (reviews == 1) {
    nextInterval = 6;
  } else {
    nextInterval = (interval * e).clamp(1, 365);
  }
  final nextMs =
      nowMs + (nextInterval * 24 * 60 * 60 * 1000).round();
  return (interval: nextInterval, ease: e, nextMs: nextMs);
}

/// Exam question model (parsed from AI JSON).
class QuizQ {
  final String q;
  final String type; // mcq | tf | short
  final List<String> options;
  final String answer; // exact correct text (or 'true'/'false')
  final String explanation;
  final int page; // PDF page where the question appears (0 = unknown)
  QuizQ({required this.q, required this.type, this.options = const [],
    required this.answer, this.explanation = '', this.page = 0});

  factory QuizQ.fromJson(Map<String, dynamic> j) => QuizQ(
    q: '${j['q'] ?? ''}',
    type: '${j['type'] ?? 'mcq'}',
    options: ((j['options'] as List?) ?? []).map((e) => '$e').toList(),
    answer: '${j['answer'] ?? ''}',
    explanation: '${j['explanation'] ?? ''}',
    page: (j['page'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'q': q, 'type': type, 'options': options,
    'answer': answer, 'explanation': explanation, 'page': page,
  };
}

List<QuizQ> parseQuestions(String jsonStr) {
  final cleaned = _extractJsonArray(jsonStr);
  final list = jsonDecode(cleaned) as List;
  return list.map((e) => QuizQ.fromJson(e as Map<String, dynamic>)).toList();
}

/// Pulls the first JSON array out of possibly-chatty AI output.
String _extractJsonArray(String s) {
  final start = s.indexOf('[');
  final end = s.lastIndexOf(']');
  if (start >= 0 && end > start) return s.substring(start, end + 1);
  return s;
}

/// Grades objective questions. Returns (score, maxScore, perQuestionCorrect).
({double score, double maxScore, List<bool> correct}) gradeExam(
    List<QuizQ> questions, Map<int, String> answers) {
  double score = 0;
  final correct = <bool>[];
  for (var i = 0; i < questions.length; i++) {
    final q = questions[i];
    bool ok = false;
    if (q.type == 'short') {
      ok = false; // manual grading only
    } else {
      final given = (answers[i] ?? '').trim().toLowerCase();
      final want = q.answer.trim().toLowerCase();
      ok = given.isNotEmpty && given == want;
    }
    correct.add(ok);
    if (ok) score += 1;
  }
  return (score: score, maxScore: questions.length.toDouble(), correct: correct);
}

/// Timetable overlap check: true if [startMin,endMin) overlaps any existing
/// entry on the same weekday (excluding [excludeId]).
bool hasOverlap(List<({int start, int end, String id})> existing, int weekday,
    int startMin, int endMin, {String excludeId = ''}) {
  for (final e in existing) {
    if (e.id == excludeId) continue;
    if (startMin < e.end && endMin > e.start) return true;
  }
  return false;
}

/// Countdown text parts for a due timestamp.
String countdownParts(int dueMs, int nowMs, String Function(String) tr) {
  final diff = dueMs - nowMs;
  if (diff <= 0) return tr('overdue');
  final days = diff ~/ (24 * 3600 * 1000);
  if (days >= 2) return '${tr('daysLeft')}: $days ${tr('days')}';
  if (days == 1) return tr('tomorrow');
  final hours = diff ~/ (3600 * 1000);
  if (hours >= 1) return '$hours ${tr('hoursLeft')}';
  final mins = max(1, diff ~/ (60 * 1000));
  return '$mins ${tr('minutes')}';
}

/// Average of grade entries as a percentage (0..100).
/// Each entry is (grade, maxGrade); empty list -> 0.
double gradeAverage(List<(double, double)> entries) {
  if (entries.isEmpty) return 0;
  var sum = 0.0;
  var n = 0;
  for (final e in entries) {
    if (e.$2 <= 0) continue;
    sum += e.$1 / e.$2 * 100;
    n++;
  }
  return n == 0 ? 0 : sum / n;
}
