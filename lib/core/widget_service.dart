import 'package:home_widget/home_widget.dart';
import 'l10n.dart';
import 'models.dart';
import 'store.dart';
import 'widgets.dart';

/// Pushes today's classes + next class to the home-screen widget.
class WidgetService {
  static const _androidName =
      'com.valor.studyassistant.StudyWidgetProvider';

  static Future<void> update() async {
    try {
      final now = DateTime.now();
      final entries = DB.timetable.values
          .where((e) => e.weekday == now.weekday)
          .toList()
        ..sort((a, b) => a.startMin.compareTo(b.startMin));
      final nowMin = now.hour * 60 + now.minute;
      TimetableEntry? next;
      for (final e in entries) {
        if (e.endMin > nowMin) {
          next = e;
          break;
        }
      }

      String line(TimetableEntry e) {
        final name = DB.subjectName(e.subjectId) ?? '';
        final kind =
            e.kind == 0 ? t('lecture') : t('section');
        return '${formatClock(e.startMin)}  $name ($kind)';
      }

      final lines =
          entries.take(3).map(line).toList(growable: true);
      while (lines.length < 3) {
        lines.add('');
      }
      if (entries.isEmpty) {
        lines[0] = t('noClassesToday');
      }

      final nextText = next == null
          ? ''
          : '${t('nextClass')}: ${formatClock(next.startMin)} ${DB.subjectName(next.subjectId) ?? ''}';

      await HomeWidget.saveWidgetData<String>(
          'widget_title', t('todaysClasses'));
      await HomeWidget.saveWidgetData<String>(
          'widget_line1', lines[0]);
      await HomeWidget.saveWidgetData<String>(
          'widget_line2', lines[1]);
      await HomeWidget.saveWidgetData<String>(
          'widget_line3', lines[2]);
      await HomeWidget.saveWidgetData<String>(
          'widget_next', nextText);
      await HomeWidget.updateWidget(
          qualifiedAndroidName: _androidName);
    } catch (_) {
      // widget is best-effort; never crash the app
    }
  }
}
