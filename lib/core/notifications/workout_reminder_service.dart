import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../shared/models/scheduled_workout.dart';

/// Owns Android workout reminders. Reminders are stored by Android, so they
/// continue to work when SyncroFit is closed and when the phone is offline.
class WorkoutReminderService {
  WorkoutReminderService._();

  static final instance = WorkoutReminderService._();

  static const _channelId = 'scheduled_workouts';
  static const _permissionRequestedKey = 'workout_notification_requested';
  static const _testNotificationId = 8199;
  static const _weeklyNotificationBaseId = 8200;

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  SharedPreferences? _preferences;
  bool _initialized = false;
  String? _pendingWorkoutId;
  void Function(String workoutId)? _onWorkoutSelected;

  Future<void> initialize(SharedPreferences preferences) async {
    if (_initialized || kIsWeb) return;
    _preferences = preferences;

    tz_data.initializeTimeZones();
    try {
      final localTimezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localTimezone.identifier));
    } catch (error) {
      debugPrint('Unable to determine local timezone: $error');
      tz.setLocalLocation(tz.UTC);
    }

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('ic_launcher'),
    );
    await _notifications.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
    );

    const channel = AndroidNotificationChannel(
      _channelId,
      'Scheduled workouts',
      description: 'Reminders for workout days in your accepted weekly plan.',
      importance: Importance.high,
    );
    await _androidPlugin?.createNotificationChannel(channel);

    final launchDetails = await _notifications.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      _pendingWorkoutId = launchDetails?.notificationResponse?.payload;
    }
    _initialized = true;
  }

  AndroidFlutterLocalNotificationsPlugin? get _androidPlugin => _notifications
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  void setWorkoutNavigationHandler(void Function(String workoutId) handler) {
    _onWorkoutSelected = handler;
    final pending = _pendingWorkoutId;
    if (pending != null && pending.isNotEmpty) {
      _pendingWorkoutId = null;
      handler(pending);
    }
  }

  void _handleNotificationResponse(NotificationResponse response) {
    final workoutId = response.payload;
    if (workoutId == null || workoutId.isEmpty) return;
    final handler = _onWorkoutSelected;
    if (handler == null) {
      _pendingWorkoutId = workoutId;
    } else {
      handler(workoutId);
    }
  }

  Future<void> scheduleWeeklyPlan(List<ScheduledWorkout> workouts) async {
    if (!_initialized || kIsWeb) return;
    try {
      await cancelWeeklyPlan();
      if (workouts.isEmpty || !await _requestPermissionOnce()) return;

      for (final workout in workouts) {
        final weekday = workout.dayOfWeek.index + 1;
        await _notifications.zonedSchedule(
          id: _weeklyNotificationBaseId + workout.dayOfWeek.index,
          title: 'Workout scheduled today',
          body: '${workout.workoutName} is ready. Open SyncroFit to begin.',
          scheduledDate: _nextOccurrence(weekday, 8),
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              _channelId,
              'Scheduled workouts',
              channelDescription:
                  'Reminders for workout days in your accepted weekly plan.',
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          payload: workout.workoutId,
        );
      }
    } catch (error, stack) {
      debugPrint('Unable to schedule workout reminders: $error');
      debugPrint('$stack');
    }
  }

  Future<bool> showTestReminder() async {
    if (!_initialized || kIsWeb) return false;
    try {
      final allowed = await _androidPlugin?.requestNotificationsPermission();
      _preferences?.setBool(_permissionRequestedKey, true);
      if (allowed == false) return false;
      await _notifications.show(
        id: _testNotificationId,
        title: 'SyncroFit workout reminder',
        body: 'Notifications are ready for your scheduled workout days.',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            'Scheduled workouts',
            channelDescription:
                'Reminders for workout days in your accepted weekly plan.',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
      return true;
    } catch (error) {
      debugPrint('Unable to show test workout reminder: $error');
      return false;
    }
  }

  Future<void> cancelWeeklyPlan() async {
    if (!_initialized || kIsWeb) return;
    for (var day = 0; day < 7; day++) {
      await _notifications.cancel(id: _weeklyNotificationBaseId + day);
    }
  }

  Future<bool> _requestPermissionOnce() async {
    final preferences = _preferences;
    if (preferences?.getBool(_permissionRequestedKey) ?? false) return true;
    final allowed = await _androidPlugin?.requestNotificationsPermission();
    await preferences?.setBool(_permissionRequestedKey, true);
    return allowed ?? true;
  }

  tz.TZDateTime _nextOccurrence(int weekday, int hour) {
    final now = tz.TZDateTime.now(tz.local);
    var result = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
    );
    while (result.weekday != weekday || !result.isAfter(now)) {
      result = result.add(const Duration(days: 1));
    }
    return result;
  }
}
