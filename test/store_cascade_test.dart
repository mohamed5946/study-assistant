import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:study_assistant/core/models.dart';
import 'package:study_assistant/core/store.dart';

/// Regression test for the v2.3 fix: deleting a subject used to orphan
/// timetable entries, deadlines, documents, flashcards, exams, attendance,
/// grades, notes and pomodoro records. [DB.deleteSubjectCascade] must remove
/// them all while leaving other subjects' records untouched.
void main() {
  late Directory tmp;

  setUpAll(() async {
    tmp = await Directory.systemTemp.createTemp('sa_cascade_test');
    Hive.init(tmp.path);
    registerAdapters();
    DB.subjects = await Hive.openBox<Subject>('subjects');
    DB.timetable = await Hive.openBox<TimetableEntry>('timetable');
    DB.deadlines = await Hive.openBox<Deadline>('deadlines');
    DB.documents = await Hive.openBox<StudyDocument>('documents');
    DB.flashcards = await Hive.openBox<Flashcard>('flashcards');
    DB.exams = await Hive.openBox<Exam>('exams');
    DB.attempts = await Hive.openBox<ExamAttempt>('attempts');
    DB.attendance = await Hive.openBox<AttendanceRecord>('attendance');
    DB.grades = await Hive.openBox<GradeRecord>('grades');
    DB.notes = await Hive.openBox<Note>('notes');
    DB.pomodoro = await Hive.openBox<PomodoroSession>('pomodoro');
  });

  tearDownAll(() async {
    await Hive.close();
    await tmp.delete(recursive: true);
  });

  test('cascade deletes all records of the subject only', () async {
    const doomed = 's_doomed';
    const survivor = 's_survivor';

    Future<void> seed(String sid) async {
      await DB.subjects.put(sid, Subject(id: sid, name: sid, colorValue: 0xFF3E7BFA));
      await DB.timetable.put('tt_$sid',
          TimetableEntry(id: 'tt_$sid', subjectId: sid, weekday: 1, startMin: 480, endMin: 540));
      await DB.deadlines.put('dl_$sid',
          Deadline(id: 'dl_$sid', subjectId: sid, title: 't', dueMs: 1));
      await DB.documents.put('doc_$sid',
          StudyDocument(id: 'doc_$sid', subjectId: sid, name: 'n', path: '/nonexistent/$sid.pdf', importedMs: 1));
      await DB.flashcards.put('fc_$sid',
          Flashcard(id: 'fc_$sid', subjectId: sid, front: 'q', back: 'a', nextReviewMs: 1));
      await DB.exams.put('ex_$sid',
          Exam(id: 'ex_$sid', title: 'e', subjectId: sid, questionsJson: '[]', createdMs: 1));
      await DB.attempts.put('att_$sid',
          ExamAttempt(id: 'att_$sid', examId: 'ex_$sid', answersJson: '[]', score: 1, maxScore: 2, startedMs: 1, finishedMs: 2));
      await DB.attendance.put('ar_$sid',
          AttendanceRecord(id: 'ar_$sid', subjectId: sid, dayMs: 1, status: 1));
      await DB.grades.put('gr_$sid',
          GradeRecord(id: 'gr_$sid', subjectId: sid, name: 'mid', score: 80, maxScore: 100));
      await DB.notes.put('nt_$sid',
          Note(id: 'nt_$sid', subjectId: sid, title: 't', text: 'x', createdMs: 1, updatedMs: 1));
      await DB.pomodoro.put('pm_$sid',
          PomodoroSession(id: 'pm_$sid', subjectId: sid, startMs: 1, focusMin: 25, breakMin: 5));
    }

    await seed(doomed);
    await seed(survivor);

    await DB.deleteSubjectCascade(doomed);

    // Everything belonging to the deleted subject is gone.
    expect(DB.subjects.containsKey(doomed), isFalse);
    for (final box in [
      DB.timetable, DB.deadlines, DB.documents, DB.flashcards, DB.exams,
      DB.attempts, DB.attendance, DB.grades, DB.notes, DB.pomodoro,
    ]) {
      expect(box.values.any((v) {
        final m = (v as dynamic);
        return (m.subjectId as String?) == doomed ||
            (m is ExamAttempt && m.examId == 'ex_$doomed');
      }), isFalse, reason: 'orphan left in ${box.name}');
    }

    // The other subject and all its records survive.
    expect(DB.subjects.containsKey(survivor), isTrue);
    expect(DB.timetable.containsKey('tt_$survivor'), isTrue);
    expect(DB.deadlines.containsKey('dl_$survivor'), isTrue);
    expect(DB.flashcards.containsKey('fc_$survivor'), isTrue);
    expect(DB.attempts.containsKey('att_$survivor'), isTrue);
    expect(DB.grades.containsKey('gr_$survivor'), isTrue);
    expect(DB.notes.containsKey('nt_$survivor'), isTrue);
  });
}
