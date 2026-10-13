import 'package:hive_flutter/hive_flutter.dart';
export 'package:hive_flutter/hive_flutter.dart';
import 'models.dart';

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

  static String get aiProvider =>
      DB.kv.get('aiProvider', defaultValue: 'gemini') as String;
  static set aiProvider(String v) => DB.kv.put('aiProvider', v);

  static String get aiKey => DB.kv.get('aiKey', defaultValue: '') as String;
  static set aiKey(String v) => DB.kv.put('aiKey', v);

  static String get aiBaseUrl =>
      DB.kv.get('aiBaseUrl', defaultValue: _defaultBaseUrl) as String;
  static set aiBaseUrl(String v) => DB.kv.put('aiBaseUrl', v);

  static String get aiModel =>
      DB.kv.get('aiModel', defaultValue: _defaultModel) as String;
  static set aiModel(String v) => DB.kv.put('aiModel', v);

  /// Free Groq defaults are pre-filled when the OpenAI-compatible
  /// provider is selected (no key is ever embedded — the user pastes his own).
  static String get _defaultBaseUrl => aiProvider == 'openai'
      ? 'https://api.groq.com/openai/v1'
      : 'https://api.openai.com/v1';
  static String get _defaultModel => aiProvider == 'openai'
      ? 'openai/gpt-oss-20b'
      : 'gemini-3.8-flash';

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
}
