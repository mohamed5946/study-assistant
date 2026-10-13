import 'dart:io';

import 'package:hive_flutter/hive_flutter.dart';
export 'package:hive_flutter/hive_flutter.dart';
import 'models.dart';
import 'notify.dart';

/// Central access to all Hive boxes.
class DB {
  static late Box<Subject> subjects;
  static late Box<TimetableEntry> timetable;
  static late Box<Deadline> deadlines;
  static late Box<ChatMessage> chat;
  static late Box<StudyDocument> documents;
  static late Box<Flashcard> flashcards;
  static late Box<Exam> exams;
  static late Box<ExamAttempt> attempts;
  static late Box<AttendanceRecord> attendance;
  static late Box<GradeRecord> grades;
  static late Box<Note> notes;
  static late Box<PomodoroSession> pomodoro;
  static late Box<TermGrade> termGrades;
  static late Box<TermGpa> termGpas; // simplified per-term GPA records
  static late Box kv; // settings key-value

  static Future<void> init() async {
    await Hive.initFlutter();
    registerAdapters();
    subjects = await Hive.openBox<Subject>('subjects');
    timetable = await Hive.openBox<TimetableEntry>('timetable');
    deadlines = await Hive.openBox<Deadline>('deadlines');
    chat = await Hive.openBox<ChatMessage>('chat');
    documents = await Hive.openBox<StudyDocument>('documents');
    flashcards = await Hive.openBox<Flashcard>('flashcards');
    exams = await Hive.openBox<Exam>('exams');
    attempts = await Hive.openBox<ExamAttempt>('attempts');
    attendance = await Hive.openBox<AttendanceRecord>('attendance');
    grades = await Hive.openBox<GradeRecord>('grades');
    notes = await Hive.openBox<Note>('notes');
    pomodoro = await Hive.openBox<PomodoroSession>('pomodoro');
    termGrades = await Hive.openBox<TermGrade>('termGrades');
    termGpas = await Hive.openBox<TermGpa>('termGpa');
    kv = await Hive.openBox('kv');
  }

  static Future<void> clearAll() async {
    for (final b in [subjects, timetable, deadlines, chat, documents,
      flashcards, exams, attempts, attendance, grades, notes, pomodoro]) {
      await b.clear();
    }
  }

  static String? subjectName(String id) {
    if (id.isEmpty) return null;
    return subjects.get(id)?.name;
  }

  static int subjectColor(String id, {int fallback = 0xFF3E7BFA}) {
    if (id.isEmpty) return fallback;
    return subjects.get(id)?.colorValue ?? fallback;
  }
}

/// App settings stored in the kv box (on-device only).
class Settings {
  static String get lang => DB.kv.get('lang', defaultValue: 'ar') as String;
  static set lang(String v) => DB.kv.put('lang', v);

  static String get theme =>
      DB.kv.get('theme', defaultValue: 'system') as String;
  static set theme(String v) => DB.kv.put('theme', v);

  /// Bundled Groq config — the single source of AI settings. There is no
  /// provider/key UI anywhere in the app; main.dart applies these from the
  /// build-time --dart-define on every launch.
  static String get aiKey => DB.kv.get('aiKey', defaultValue: '') as String;
  static set aiKey(String v) => DB.kv.put('aiKey', v);

  static String get aiBaseUrl => DB.kv.get('aiBaseUrl',
      defaultValue: 'https://api.groq.com/openai/v1') as String;
  static set aiBaseUrl(String v) => DB.kv.put('aiBaseUrl', v);

  static String get aiModel => DB.kv.get('aiModel',
      defaultValue: 'openai/gpt-oss-20b') as String;
  static set aiModel(String v) => DB.kv.put('aiModel', v);

  static int get focusMin => DB.kv.get('focusMin', defaultValue: 25) as int;
  static set focusMin(int v) => DB.kv.put('focusMin', v);

  static int get breakMin => DB.kv.get('breakMin', defaultValue: 5) as int;
  static set breakMin(int v) => DB.kv.put('breakMin', v);

  static int get attendanceThreshold =>
      DB.kv.get('attendanceThreshold', defaultValue: 75) as int;
  static set attendanceThreshold(int v) =>
      DB.kv.put('attendanceThreshold', v);

  static bool get hasAiKey => aiKey.trim().isNotEmpty;

  // ---- Profile (local only) ----
  static String get profileName =>
      DB.kv.get('profileName', defaultValue: '') as String;
  static set profileName(String v) => DB.kv.put('profileName', v);

  static String get university =>
      DB.kv.get('university', defaultValue: '') as String;
  static set university(String v) => DB.kv.put('university', v);

  static String get faculty =>
      DB.kv.get('faculty', defaultValue: '') as String;
  static set faculty(String v) => DB.kv.put('faculty', v);

  static int get academicYear =>
      DB.kv.get('academicYear', defaultValue: 1) as int;
  static set academicYear(int v) => DB.kv.put('academicYear', v);

  static String get profilePhoto =>
      DB.kv.get('profilePhoto', defaultValue: '') as String;
  static set profilePhoto(String v) => DB.kv.put('profilePhoto', v);

  /// Deletes a subject and every record that references it (timetable
  /// entries + their class reminders, deadlines + their reminders, PDF
  /// documents + files, flashcards, exams + attempts, attendance, grades,
  /// notes, pomodoro sessions). Prevents orphaned records that would show
  /// broken "—" names elsewhere in the app.
  static Future<void> deleteSubjectCascade(String sid) async {
    Future<void> deleteWhere<T>(Box<T> box, bool Function(T) match) async {
      final keys = box.keys
          .where((k) => match(box.get(k) as T))
          .toList();
      for (final k in keys) {
        await box.delete(k);
      }
    }

    final classKeys = timetable.keys
        .where((k) => (timetable.get(k) as TimetableEntry).subjectId == sid)
        .toList();
    for (final k in classKeys) {
      final e = timetable.get(k) as TimetableEntry;
      await Notify.cancel('class_${e.id}');
      await timetable.delete(k);
    }
    final deadlineKeys = deadlines.keys
        .where((k) => (deadlines.get(k) as Deadline).subjectId == sid)
        .toList();
    for (final k in deadlineKeys) {
      final d = deadlines.get(k) as Deadline;
      await Notify.cancel('deadline_${d.id}');
      await deadlines.delete(k);
    }
    final docKeys = documents.keys
        .where((k) => (documents.get(k) as StudyDocument).subjectId == sid)
        .toList();
    for (final k in docKeys) {
      final doc = documents.get(k) as StudyDocument;
      try {
        await File(doc.path).delete();
      } catch (_) {}
      await documents.delete(k);
    }
    await deleteWhere<Flashcard>(
        flashcards, (f) => f.subjectId == sid);
    final examIds = exams.values
        .where((e) => e.subjectId == sid)
        .map((e) => e.id)
        .toSet();
    await deleteWhere<ExamAttempt>(
        attempts, (a) => examIds.contains(a.examId));
    await deleteWhere<Exam>(exams, (e) => e.subjectId == sid);
    await deleteWhere<AttendanceRecord>(
        attendance, (a) => a.subjectId == sid);
    await deleteWhere<GradeRecord>(grades, (g) => g.subjectId == sid);
    await deleteWhere<Note>(notes, (n) => n.subjectId == sid);
    await deleteWhere<PomodoroSession>(
        pomodoro, (p) => p.subjectId == sid);
    await subjects.delete(sid);
  }
}
