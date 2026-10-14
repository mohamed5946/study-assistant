import 'package:add_2_calendar/add_2_calendar.dart';

/// Opens the device calendar app with a prefilled event (intent-based).
/// No calendar permissions needed — the user confirms in their calendar app.
/// Replaces the device_calendar implementation, which conflicted with the
/// app's timezone version.
class CalendarHelper {
  /// Fires the calendar intent. Returns true if the intent was launched.
  static Future<bool> addEvent({
    required String title,
    required DateTime start,
    required DateTime end,
    String description = '',
    String location = '',
    bool weekly = false,
    int reminderMinutes = 0,
  }) {
    final event = Event(
      title: title,
      description: description,
      location: location,
      startDate: start,
      endDate: end,
      allDay: false,
      iosParams: IOSParams(
        reminder: Duration(minutes: reminderMinutes),
      ),
      androidParams: const AndroidParams(),
      recurrence:
          weekly ? Recurrence(frequency: Frequency.weekly) : null,
    );
    return Add2Calendar.addEvent2Cal(event);
  }
}
