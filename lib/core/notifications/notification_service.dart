import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Wraps [FlutterLocalNotificationsPlugin] for Scampi's on-device-only
/// notifications (no push/FCM — everything is scheduled locally, in
/// keeping with the app being fully offline-first). Currently used for
/// the fasting-complete reminder; the channel/init plumbing here is
/// meant to be reused for future notification types too.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _fastingChannelId = 'scampi_fasting';
  static const _fastingChannelName = 'Fasting';
  static const _fastingChannelDescription =
      'Notifies you when your fasting target duration is reached.';

  /// Fast-completion notifications use this fixed id — there's only ever
  /// one active fast at a time, so scheduling a new one naturally
  /// replaces (and ending a fast early cancels) the previous one.
  static const int fastingCompleteNotificationId = 1001;

  Future<void> init() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(initSettings);

    const channel = AndroidNotificationChannel(
      _fastingChannelId,
      _fastingChannelName,
      description: _fastingChannelDescription,
      importance: Importance.high,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    _initialized = true;
  }

  /// Requests the runtime POST_NOTIFICATIONS permission (Android 13+ —
  /// a no-op on older versions where it's granted at install time).
  /// Returns whether permission is granted.
  Future<bool> requestPermission() async {
    await init();
    final granted = await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    return granted ?? false;
  }

  /// Schedules the "your fast is complete" notification for [targetEnd].
  /// If [targetEnd] is already in the past, does nothing (there's
  /// nothing useful to notify about after the fact).
  Future<void> scheduleFastingComplete(DateTime targetEnd) async {
    await init();
    if (targetEnd.isBefore(DateTime.now())) return;

    await _plugin.zonedSchedule(
      fastingCompleteNotificationId,
      'Fast complete! 🎉',
      "You've hit your fasting target — nice work.",
      tz.TZDateTime.from(targetEnd, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _fastingChannelId,
          _fastingChannelName,
          channelDescription: _fastingChannelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Cancels a pending fast-complete notification — used when a fast is
  /// ended manually before reaching its target.
  Future<void> cancelFastingComplete() async {
    await init();
    await _plugin.cancel(fastingCompleteNotificationId);
  }
}
