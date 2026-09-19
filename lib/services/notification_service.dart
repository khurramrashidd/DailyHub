import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Schedules real OS-level local notifications that fire even when the app
/// is fully closed. This is the "reminders that alert when app is closed"
/// capability. Works on Android & iOS.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  /// Local notifications are not supported on Flutter web. Every method
  /// no-ops there so the shared codebase runs unchanged in the browser.
  bool get supported => !kIsWeb;

  Future<void> init() async {
    if (kIsWeb || _ready) return;

    tzdata.initializeTimeZones();
    try {
      final localZone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localZone));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
    }

    const androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings =
        InitializationSettings(android: androidInit, iOS: iosInit);

    await _plugin.initialize(settings);
    _ready = true;
  }

  /// Ask for permission (Android 13+, iOS). Call after login.
  Future<void> requestPermissions() async {
    if (kIsWeb) return;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();

    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    await ios?.requestPermissions(alert: true, badge: true, sound: true);
  }

  NotificationDetails get _details => const NotificationDetails(
        android: AndroidNotificationDetails(
          'dailyhub_reminders',
          'Reminders',
          channelDescription: 'Reminders, to-do deadlines and trip alerts',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      );

  /// Deterministic 31-bit id from a string key so we can cancel/replace.
  int idFor(String key) => key.hashCode & 0x7fffffff;

  Future<void> scheduleAt({
    required String key,
    required String title,
    required String body,
    required DateTime when,
  }) async {
    if (kIsWeb) return;
    if (!_ready) await init();
    if (when.isBefore(DateTime.now())) return;
    try {
      await _plugin.zonedSchedule(
        idFor(key),
        title,
        body,
        tz.TZDateTime.from(when, tz.local),
        _details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('schedule error: $e');
    }
  }

  Future<void> cancel(String key) async {
    if (kIsWeb) return;
    await _plugin.cancel(idFor(key));
  }

  Future<void> showNow(String title, String body) async {
    if (kIsWeb) return;
    if (!_ready) await init();
    await _plugin.show(
        DateTime.now().millisecondsSinceEpoch & 0x7fffffff,
        title,
        body,
        _details);
  }
}
