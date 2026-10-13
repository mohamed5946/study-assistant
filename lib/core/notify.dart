import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

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
      settings: const InitializationSettings(android: android),
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

  /// Stable 31-bit id for a key. String.hashCode is NOT stable across
  /// VM launches, so a persisted FNV-1a hash is used instead — otherwise
  /// cancel(key) would miss reminders scheduled before a restart and
  /// re-scheduling would pile up duplicates.
  static int idFor(String key) {
    var h = 0x811c9dc5;
    for (final c in key.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xffffffff;
    }
    return h & 0x7fffffff;
  }

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
    // A reminder can't fire before midnight of the class day: clamp.
    final before = minutesBefore.clamp(0, classStartMin);
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day,
            classStartMin ~/ 60, classStartMin % 60)
        .subtract(Duration(minutes: before));
    while (scheduled.weekday != weekday || scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    try {
      await _plugin.zonedSchedule(
        id: idFor(key),
        title: title,
        body: body,
        scheduledDate: scheduled,
        notificationDetails: const NotificationDetails(
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
        id: idFor(key),
        title: title,
        body: body,
        scheduledDate: scheduled,
        notificationDetails: const NotificationDetails(
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
        id: idFor(key),
        title: title,
        body: body,
        scheduledDate: when,
        notificationDetails: const NotificationDetails(
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
        id: idFor(key),
        title: title,
        body: body,
        scheduledDate: when,
        notificationDetails: const NotificationDetails(
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
    await _plugin.cancel(id: idFor(key));
  }
}
