import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart';
import 'l10n.dart';

/// Small helper around device_calendar: requests permissions, picks the
/// default calendar, and creates events. Shows a snackbar with the result.
class CalendarHelper {
  static final DeviceCalendarPlugin _plugin = DeviceCalendarPlugin();

  /// Returns true if the event was created.
  static Future<bool> addEvent({
    required BuildContext context,
    required String title,
    required DateTime start,
    required DateTime end,
    String description = '',
    RecurrenceRule? recurrence,
    List<Reminder>? reminders,
  }) async {
    // 1. Permissions
    var perm = await _plugin.hasPermissions();
    if (!(perm.isSuccess && (perm.data ?? false))) {
      perm = await _plugin.requestPermissions();
      if (!(perm.isSuccess && (perm.data ?? false))) {
        _snack(context, t('calendarFailed'));
        return false;
      }
    }
    // 2. Default calendar
    final cals = await _plugin.retrieveCalendars();
    if (!cals.isSuccess || cals.data == null || cals.data!.isEmpty) {
      _snack(context, t('calendarFailed'));
      return false;
    }
    final cal = cals.data!.firstWhere(
      (c) => c.isDefault ?? false,
      orElse: () => cals.data!.first,
    );
    // 3. Create event
    final event = Event(
      cal.id,
      title: title,
      description: description,
      start: TZDateTime.from(start, local),
      end: TZDateTime.from(end, local),
      recurrenceRule: recurrence,
      reminders: reminders ?? [],
    );
    final res = await _plugin.createOrUpdateEvent(event);
    final ok = res?.isSuccess == true && (res?.data?.isNotEmpty ?? false);
    _snack(context, ok ? t('calendarAdded') : t('calendarFailed'));
    return ok;
  }

  static void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }
}
