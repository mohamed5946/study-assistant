import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'l10n.dart';

class Notify {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static Future<void> init() async {
    tzdata.initializeTimeZones();
    try {
      final name = (await FlutterTimezone.getLocalTimezone()).identifier;
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Africa/Cairo'));
    }
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: android),
      onDidReceiveNotificationResponse: (_) {},
    );
    const channel = AndroidNotificationChannel(
      'study_reminders',
      'Study reminders',
      importance: Importance.high,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
    _ready = true;
  }

  static Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final notif = await android?.requestNotificationsPermission() ?? false;
    try {
      await android?.requestExactAlarmsPermission();
    } catch (_) {}
    return notif;
  }

  static int _idFor(String key) => key.hashCode & 0x7fffffff;

  /// Schedules a weekly class reminder. [weekday]: 1=Mon..7=Sun.
  static Future<void> scheduleClass({
    required String key,
    required String title,
    required String body,
    required int weekday,
    required int minutesBefore,
    required int classStartMin,
  }) async {
    if (!_ready) return;
    await cancel(key);
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day,
            classStartMin ~/ 60, classStartMin % 60)
        .subtract(Duration(minutes: minutesBefore));
    while (scheduled.weekday != weekday || scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    try {
      await _plugin.zonedSchedule(
        _idFor(key),
        title,
        body,
        scheduled,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'study_reminders',
            'Study reminders',
            importance: Importance.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    } catch (_) {
      // Fallback without exact alarms.
      await _plugin.zonedSchedule(
        _idFor(key),
        title,
        body,
        scheduled,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'study_reminders',
            'Study reminders',
            importance: Importance.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  static Future<void> scheduleOnce({
    required String key,
    required String title,
    required String body,
    required DateTime at,
  }) async {
    if (!_ready) return;
    await cancel(key);
    final when = tz.TZDateTime.from(at, tz.local);
    if (when.isBefore(tz.TZDateTime.now(tz.local))) return;
    try {
      await _plugin.zonedSchedule(
        _idFor(key),
        title,
        body,
        when,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'study_reminders',
            'Study reminders',
            importance: Importance.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (_) {
      await _plugin.zonedSchedule(
        _idFor(key),
        title,
        body,
        when,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'study_reminders',
            'Study reminders',
            importance: Importance.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  static Future<void> cancel(String key) async {
    if (!_ready) return;
    await _plugin.cancel(_idFor(key));
  }

  static String channelName() => t('notificationChannel');
}
