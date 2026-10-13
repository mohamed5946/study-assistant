import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();
String newId() => _uuid.v4();

int dayStartMs(DateTime d) => DateTime(d.year, d.month, d.day).millisecondsSinceEpoch;

// ---------------- Subject ----------------
class Subject {
  String id, name, code;
  int colorValue;
  double creditHours;
  Subject({required this.id, required this.name, this.code = '', required this.colorValue, this.creditHours = 3});
}

class SubjectAdapter extends TypeAdapter<Subject> {
  @override final int typeId = 0;
  @override Subject read(BinaryReader r) => Subject(
    id: r.readString(), name: r.readString(), code: r.readString(),
    colorValue: r.readInt(), creditHours: r.readDouble());
  @override void write(BinaryWriter w, Subject o) {
    w.writeString(o.id); w.writeString(o.name); w.writeString(o.code);
    w.writeInt(o.colorValue); w.writeDouble(o.creditHours);
  }
}

// ---------------- TimetableEntry ----------------
class TimetableEntry {
  String id, subjectId, place, instructor;
  int kind; // 0 lecture, 1 section
  int weekday; // 1=Mon..7=Sun
  int startMin, endMin, reminderMin; // reminderMin: -1 none
  TimetableEntry({required this.id, required this.subjectId, this.kind = 0,
    required this.weekday, required this.startMin, required this.endMin,
    this.place = '', this.instructor = '', this.reminderMin = -1});
}

class TimetableEntryAdapter extends TypeAdapter<TimetableEntry> {
  @override final int typeId = 1;
  @override TimetableEntry read(BinaryReader r) => TimetableEntry(
    id: r.readString(), subjectId: r.readString(), kind: r.readInt(),
    weekday: r.readInt(), startMin: r.readInt(), endMin: r.readInt(),
    place: r.readString(), instructor: r.readString(), reminderMin: r.readInt());
  @override void write(BinaryWriter w, TimetableEntry o) {
    w.writeString(o.id); w.writeString(o.subjectId); w.writeInt(o.kind);
    w.writeInt(o.weekday); w.writeInt(o.startMin); w.writeInt(o.endMin);
    w.writeString(o.place); w.writeString(o.instructor); w.writeInt(o.reminderMin);
  }
}

// ---------------- Deadline ----------------
class Deadline {
  String id, subjectId, title, notes;
  int kind; // 0 exam, 1 assignment
  int dueMs;
  bool done;
  int reminderMin;
  Deadline({required this.id, this.subjectId = '', required this.title, this.kind = 0,
    required this.dueMs, this.notes = '', this.done = false, this.reminderMin = -1});
}

class DeadlineAdapter extends TypeAdapter<Deadline> {
  @override final int typeId = 2;
  @override Deadline read(BinaryReader r) => Deadline(
    id: r.readString(), subjectId: r.readString(), title: r.readString(),
    kind: r.readInt(), dueMs: r.readInt(), notes: r.readString(),
    done: r.readBool(), reminderMin: r.readInt());
  @override void write(BinaryWriter w, Deadline o) {
    w.writeString(o.id); w.writeString(o.subjectId); w.writeString(o.title);
    w.writeInt(o.kind); w.writeInt(o.dueMs); w.writeString(o.notes);
    w.writeBool(o.done); w.writeInt(o.reminderMin);
  }
}

// ---------------- ChatMessage ----------------
class ChatMessage {
  String id, text;
  int role; // 0 user, 1 assistant
  int createdMs;
  ChatMessage({required this.id, required this.role, required this.text, required this.createdMs});
}

class ChatMessageAdapter extends TypeAdapter<ChatMessage> {
  @override final int typeId = 3;
  @override ChatMessage read(BinaryReader r) => ChatMessage(
    id: r.readString(), role: r.readInt(), text: r.readString(), createdMs: r.readInt());
  @override void write(BinaryWriter w, ChatMessage o) {
    w.writeString(o.id); w.writeInt(o.role); w.writeString(o.text); w.writeInt(o.createdMs);
  }
}

// ---------------- StudyDocument ----------------
class StudyDocument {
  String id, subjectId, name, path;
  int importedMs;
  StudyDocument({required this.id, this.subjectId = '', required this.name, required this.path, required this.importedMs});
}

class StudyDocumentAdapter extends TypeAdapter<StudyDocument> {
  @override final int typeId = 4;
  @override StudyDocument read(BinaryReader r) => StudyDocument(
    id: r.readString(), subjectId: r.readString(), name: r.readString(),
    path: r.readString(), importedMs: r.readInt());
  @override void write(BinaryWriter w, StudyDocument o) {
    w.writeString(o.id); w.writeString(o.subjectId); w.writeString(o.name);
    w.writeString(o.path); w.writeInt(o.importedMs);
  }
}

// ---------------- Flashcard ----------------
class Flashcard {
  String id, subjectId, documentId, front, back;
  int nextReviewMs, reviews;
  double intervalDays, ease;
  Flashcard({required this.id, this.subjectId = '', this.documentId = '',
    required this.front, required this.back, required this.nextReviewMs,
    this.intervalDays = 1, this.ease = 2.5, this.reviews = 0});
}

class FlashcardAdapter extends TypeAdapter<Flashcard> {
  @override final int typeId = 5;
  @override Flashcard read(BinaryReader r) => Flashcard(
    id: r.readString(), subjectId: r.readString(), documentId: r.readString(),
    front: r.readString(), back: r.readString(), nextReviewMs: r.readInt(),
    intervalDays: r.readDouble(), ease: r.readDouble(), reviews: r.readInt());
  @override void write(BinaryWriter w, Flashcard o) {
    w.writeString(o.id); w.writeString(o.subjectId); w.writeString(o.documentId);
    w.writeString(o.front); w.writeString(o.back); w.writeInt(o.nextReviewMs);
    w.writeDouble(o.intervalDays); w.writeDouble(o.ease); w.writeInt(o.reviews);
  }
}

// ---------------- Exam ----------------
class Exam {
  String id, title, subjectId, documentId, questionsJson;
  int durationMin, createdMs;
  Exam({required this.id, required this.title, this.subjectId = '', this.documentId = '',
    this.durationMin = 30, required this.questionsJson, required this.createdMs});
}

class ExamAdapter extends TypeAdapter<Exam> {
  @override final int typeId = 6;
  @override Exam read(BinaryReader r) => Exam(
    id: r.readString(), title: r.readString(), subjectId: r.readString(),
    documentId: r.readString(), durationMin: r.readInt(),
    questionsJson: r.readString(), createdMs: r.readInt());
  @override void write(BinaryWriter w, Exam o) {
    w.writeString(o.id); w.writeString(o.title); w.writeString(o.subjectId);
    w.writeString(o.documentId); w.writeInt(o.durationMin);
    w.writeString(o.questionsJson); w.writeInt(o.createdMs);
  }
}

// ---------------- ExamAttempt ----------------
class ExamAttempt {
  String id, examId, answersJson;
  double score, maxScore;
  int startedMs, finishedMs;
  ExamAttempt({required this.id, required this.examId, required this.answersJson,
    required this.score, required this.maxScore, required this.startedMs, required this.finishedMs});
}

class ExamAttemptAdapter extends TypeAdapter<ExamAttempt> {
  @override final int typeId = 7;
  @override ExamAttempt read(BinaryReader r) => ExamAttempt(
    id: r.readString(), examId: r.readString(), answersJson: r.readString(),
    score: r.readDouble(), maxScore: r.readDouble(),
    startedMs: r.readInt(), finishedMs: r.readInt());
  @override void write(BinaryWriter w, ExamAttempt o) {
    w.writeString(o.id); w.writeString(o.examId); w.writeString(o.answersJson);
    w.writeDouble(o.score); w.writeDouble(o.maxScore);
    w.writeInt(o.startedMs); w.writeInt(o.finishedMs);
  }
}

// ---------------- AttendanceRecord ----------------
class AttendanceRecord {
  String id, subjectId, entryId;
  int dayMs, status; // 0 absent, 1 present
  AttendanceRecord({required this.id, required this.subjectId, this.entryId = '',
    required this.dayMs, required this.status});
}

class AttendanceRecordAdapter extends TypeAdapter<AttendanceRecord> {
  @override final int typeId = 8;
  @override AttendanceRecord read(BinaryReader r) => AttendanceRecord(
    id: r.readString(), subjectId: r.readString(), entryId: r.readString(),
    dayMs: r.readInt(), status: r.readInt());
  @override void write(BinaryWriter w, AttendanceRecord o) {
    w.writeString(o.id); w.writeString(o.subjectId); w.writeString(o.entryId);
    w.writeInt(o.dayMs); w.writeInt(o.status);
  }
}

// ---------------- GradeRecord ----------------
class GradeRecord {
  String id, subjectId, name;
  double score, maxScore, creditHours;
  GradeRecord({required this.id, required this.subjectId, required this.name,
    required this.score, required this.maxScore, this.creditHours = 3});
}

class GradeRecordAdapter extends TypeAdapter<GradeRecord> {
  @override final int typeId = 9;
  @override GradeRecord read(BinaryReader r) => GradeRecord(
    id: r.readString(), subjectId: r.readString(), name: r.readString(),
    score: r.readDouble(), maxScore: r.readDouble(), creditHours: r.readDouble());
  @override void write(BinaryWriter w, GradeRecord o) {
    w.writeString(o.id); w.writeString(o.subjectId); w.writeString(o.name);
    w.writeDouble(o.score); w.writeDouble(o.maxScore); w.writeDouble(o.creditHours);
  }
}

// ---------------- Note ----------------
class Note {
  String id, subjectId, title, text;
  int createdMs, updatedMs;
  Note({required this.id, this.subjectId = '', required this.title, required this.text,
    required this.createdMs, required this.updatedMs});
}

class NoteAdapter extends TypeAdapter<Note> {
  @override final int typeId = 10;
  @override Note read(BinaryReader r) => Note(
    id: r.readString(), subjectId: r.readString(), title: r.readString(),
    text: r.readString(), createdMs: r.readInt(), updatedMs: r.readInt());
  @override void write(BinaryWriter w, Note o) {
    w.writeString(o.id); w.writeString(o.subjectId); w.writeString(o.title);
    w.writeString(o.text); w.writeInt(o.createdMs); w.writeInt(o.updatedMs);
  }
}

// ---------------- PomodoroSession ----------------
class PomodoroSession {
  String id, subjectId;
  int startMs, focusMin, breakMin;
  bool completed;
  PomodoroSession({required this.id, this.subjectId = '', required this.startMs,
    required this.focusMin, required this.breakMin, this.completed = false});
}

class PomodoroSessionAdapter extends TypeAdapter<PomodoroSession> {
  @override final int typeId = 11;
  @override PomodoroSession read(BinaryReader r) => PomodoroSession(
    id: r.readString(), subjectId: r.readString(), startMs: r.readInt(),
    focusMin: r.readInt(), breakMin: r.readInt(), completed: r.readBool());
  @override void write(BinaryWriter w, PomodoroSession o) {
    w.writeString(o.id); w.writeString(o.subjectId); w.writeInt(o.startMs);
    w.writeInt(o.focusMin); w.writeInt(o.breakMin); w.writeBool(o.completed);
  }
}

void registerAdapters() {
  Hive.registerAdapter(SubjectAdapter());
  Hive.registerAdapter(TimetableEntryAdapter());
  Hive.registerAdapter(DeadlineAdapter());
  Hive.registerAdapter(ChatMessageAdapter());
  Hive.registerAdapter(StudyDocumentAdapter());
  Hive.registerAdapter(FlashcardAdapter());
  Hive.registerAdapter(ExamAdapter());
  Hive.registerAdapter(ExamAttemptAdapter());
  Hive.registerAdapter(AttendanceRecordAdapter());
  Hive.registerAdapter(GradeRecordAdapter());
  Hive.registerAdapter(NoteAdapter());
  Hive.registerAdapter(PomodoroSessionAdapter());
}
