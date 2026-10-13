// Pure logic for the smart timetable import: session parsing, conflict
// detection, and day-minimizing section selection. No Flutter dependencies,
// covered by unit tests.

/// One class session extracted from the university timetable.
class ImportedSession {
  final String subject;
  final String code;
  final int weekday; // 1=Mon .. 7=Sun
  final int startMin;
  final int endMin;
  final String place;
  final String instructor;
  final String kind; // lecture | section
  final String group; // section/group label, '' if none

  const ImportedSession({
    required this.subject,
    this.code = '',
    required this.weekday,
    required this.startMin,
    required this.endMin,
    this.place = '',
    this.instructor = '',
    this.kind = 'lecture',
    this.group = '',
  });

  factory ImportedSession.fromJson(Map<String, dynamic> j) {
    return ImportedSession(
      subject: '${j['subject'] ?? ''}'.trim(),
      code: '${j['code'] ?? ''}'.trim(),
      weekday: parseWeekday('${j['day'] ?? ''}'),
      startMin: parseClock('${j['start'] ?? ''}'),
      endMin: parseClock('${j['end'] ?? ''}'),
      place: '${j['place'] ?? ''}'.trim(),
      instructor: '${j['instructor'] ?? ''}'.trim(),
      kind: '${j['kind'] ?? 'lecture'}'.trim().toLowerCase(),
      group: '${j['group'] ?? ''}'.trim(),
    );
  }

  bool get valid =>
      subject.isNotEmpty && weekday >= 1 && weekday <= 7 && endMin > startMin;
}

/// 'Mon'/'Monday'/etc (case-insensitive) -> 1..7. 0 if unknown.
int parseWeekday(String s) {
  final t = s.trim().toLowerCase();
  const days = {
    'mon': 1, 'monday': 1,
    'tue': 2, 'tues': 2, 'tuesday': 2,
    'wed': 3, 'wednesday': 3,
    'thu': 4, 'thur': 4, 'thurs': 4, 'thursday': 4,
    'fri': 5, 'friday': 5,
    'sat': 6, 'saturday': 6,
    'sun': 7, 'sunday': 7,
  };
  return days[t] ?? 0;
}

/// 'HH:MM' 24h (tolerates 'h:mm', 'HH.MM', trailing AM/PM) -> minutes. -1 if bad.
int parseClock(String s) {
  var t = s.trim().toLowerCase().replaceAll('.', ':');
  var pm = false;
  var am = false;
  if (t.endsWith('pm')) { pm = true; t = t.substring(0, t.length - 2).trim(); }
  if (t.endsWith('am')) { am = true; t = t.substring(0, t.length - 2).trim(); }
  final parts = t.split(':');
  if (parts.length != 2) return -1;
  final h = int.tryParse(parts[0].trim());
  final m = int.tryParse(parts[1].trim());
  if (h == null || m == null || m < 0 || m > 59) return -1;
  var hh = h;
  if (pm && hh < 12) hh += 12;
  if (am && hh == 12) hh = 0;
  if (hh < 0 || hh > 23) return -1;
  return hh * 60 + m;
}

/// True if two sessions overlap in time on the same weekday.
bool sessionsOverlap(ImportedSession a, ImportedSession b) {
  if (a.weekday != b.weekday) return false;
  return a.startMin < b.endMin && b.startMin < a.endMin;
}

/// True if any two sessions in the list overlap.
bool hasAnyOverlap(List<ImportedSession> sessions) {
  for (var i = 0; i < sessions.length; i++) {
    for (var j = i + 1; j < sessions.length; j++) {
      if (sessionsOverlap(sessions[i], sessions[j])) return true;
    }
  }
  return false;
}

/// Number of distinct weekdays covered.
int distinctDays(Iterable<ImportedSession> sessions) =>
    sessions.map((s) => s.weekday).toSet().length;

/// Groups sessions of one subject by their group label.
/// Sessions with no group label each become their own single-session group
/// only if there are no labeled groups; otherwise unlabeled sessions are
/// treated as common to all groups (e.g. the shared lecture).
Map<String, List<ImportedSession>> groupSessions(List<ImportedSession> sessions) {
  final labeled = <String, List<ImportedSession>>{};
  final unlabeled = <ImportedSession>[];
  for (final s in sessions) {
    if (s.group.isEmpty) {
      unlabeled.add(s);
    } else {
      labeled.putIfAbsent(s.group, () => []).add(s);
    }
  }
  if (labeled.isEmpty) return {'': sessions};
  // unlabeled (shared lectures) join every group
  final out = <String, List<ImportedSession>>{};
  for (final e in labeled.entries) {
    out[e.key] = [...unlabeled, ...e.value];
  }
  return out;
}

class OptimizeResult {
  /// subject name -> chosen sessions (one group per subject)
  final Map<String, List<ImportedSession>> picks;
  /// chosen group label per subject ('' when single/no group)
  final Map<String, String> groups;
  final int days;
  const OptimizeResult(this.picks, this.groups, this.days);
}

/// Tries every combination of one group per subject, keeps conflict-free
/// combos, and returns the one with the fewest distinct attendance days.
/// Ties break toward earlier weekly finish (smaller max end-time).
/// Returns null when no conflict-free arrangement exists.
/// [options]: subject name -> list of group options; each option is a session list.
/// [labels]: subject name -> group label per option index.
OptimizeResult? optimizeSchedule(
    Map<String, List<List<ImportedSession>>> options,
    Map<String, List<String>> labels) {
  final subjects = options.keys.toList();
  if (subjects.isEmpty) return const OptimizeResult({}, {}, 0);

  OptimizeResult? best;
  int bestScore = 1 << 30;

  void search(int idx, Map<String, List<ImportedSession>> picks,
      Map<String, String> groups, List<ImportedSession> flat) {
    if (idx == subjects.length) {
      if (hasAnyOverlap(flat)) return;
      final days = distinctDays(flat);
      // tie-break: smaller latest end-minute across the week
      var latest = 0;
      for (final s in flat) {
        final v = s.weekday * 1440 + s.endMin;
        if (v > latest) latest = v;
      }
      final score = days * 100000 + latest;
      if (score < bestScore) {
        bestScore = score;
        best = OptimizeResult(
            Map.of(picks), Map.of(groups), days);
      }
      return;
    }
    final subj = subjects[idx];
    final opts = options[subj]!;
    final lbls = labels[subj] ?? List.filled(opts.length, '');
    for (var gi = 0; gi < opts.length; gi++) {
      final sess = opts[gi];
      // prune: adding these must not overlap what's picked so far
      var ok = true;
      for (final s in sess) {
        for (final p in flat) {
          if (sessionsOverlap(s, p)) { ok = false; break; }
        }
        if (!ok) break;
      }
      if (!ok) continue;
      picks[subj] = sess;
      groups[subj] = lbls[gi];
      search(idx + 1, picks, groups, [...flat, ...sess]);
      picks.remove(subj);
      groups.remove(subj);
    }
  }

  search(0, {}, {}, []);
  return best;
}

/// Builds optimizer input from raw sessions: subject -> labeled group options.
/// Returns (options, labels) where labels[subject][i] is the group label.
({Map<String, List<List<ImportedSession>>> options, Map<String, List<String>> labels})
    buildOptions(List<ImportedSession> sessions) {
  final bySubject = <String, List<ImportedSession>>{};
  for (final s in sessions) {
    if (!s.valid) continue;
    bySubject.putIfAbsent(s.subject, () => []).add(s);
  }
  final options = <String, List<List<ImportedSession>>>{};
  final labels = <String, List<String>>{};
  for (final e in bySubject.entries) {
    final grouped = groupSessions(e.value);
    options[e.key] = grouped.values.toList();
    labels[e.key] = grouped.keys.toList();
  }
  return (options: options, labels: labels);
}

/// Names of subject pairs that have at least one overlapping session
/// (used for the "which subjects clash" message when optimization fails).
List<(String, String)> findClashingSubjects(List<ImportedSession> sessions) {
  final bySubject = <String, List<ImportedSession>>{};
  for (final s in sessions) {
    if (s.valid) bySubject.putIfAbsent(s.subject, () => []).add(s);
  }
  final names = bySubject.keys.toList();
  final out = <(String, String)>[];
  for (var i = 0; i < names.length; i++) {
    for (var j = i + 1; j < names.length; j++) {
      var clash = false;
      for (final a in bySubject[names[i]]!) {
        for (final b in bySubject[names[j]]!) {
          if (sessionsOverlap(a, b)) { clash = true; break; }
        }
        if (clash) break;
      }
      if (clash) out.add((names[i], names[j]));
    }
  }
  return out;
}

/// Score of a self-test quiz: correct = user answer matched AI answer.
({int correct, int total}) scoreSelfTest(
    List<String> aiAnswers, Map<int, String> userAnswers) {
  var correct = 0;
  for (var i = 0; i < aiAnswers.length; i++) {
    final want = aiAnswers[i].trim().toLowerCase();
    final given = (userAnswers[i] ?? '').trim().toLowerCase();
    if (given.isNotEmpty && given == want) correct++;
  }
  return (correct: correct, total: aiAnswers.length);
}

/// Extracts [p:N] page citations from an AI answer; returns page numbers.
List<int> extractPageCitations(String text) {
  final re = RegExp(r'\[p:(\d+)\]');
  return re
      .allMatches(text)
      .map((m) => int.tryParse(m.group(1) ?? '') ?? 0)
      .where((n) => n > 0)
      .toSet()
      .toList()
    ..sort();
}

/// Strips [p:N] markers for display.
String stripPageCitations(String text) =>
    text.replaceAll(RegExp(r'\s*\[p:\d+\]'), '');
