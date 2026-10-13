import 'package:flutter_test/flutter_test.dart';
import 'package:study_assistant/core/notify.dart';

void main() {
  group('v2.3 notification ID stability', () {
    test('same key always maps to same positive id', () {
      final a = Notify.idFor('deadline_abc123');
      final b = Notify.idFor('deadline_abc123');
      expect(a, equals(b));
      expect(a, greaterThanOrEqualTo(0));
    });

    test('different keys map to different ids', () {
      expect(Notify.idFor('deadline_x'), isNot(equals(Notify.idFor('class_x'))));
    });

    test('ids stay within int32 range (plugin requirement)', () {
      for (final k in ['deadline_1', 'class_2', 'pomodoro', 'x' * 100]) {
        final id = Notify.idFor(k);
        expect(id, inInclusiveRange(0, 0x7fffffff));
      }
    });
  });
}
