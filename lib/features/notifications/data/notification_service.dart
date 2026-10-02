import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const trainingReminderId = 1200;
  static const inactivityReminderId = 1201;
  static const _channelId = 'vero_training_reminders';

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    tz.initializeTimeZones();
    try {
      final timezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezone.identifier));
    } on Object {
      // UTC is safer than inventing a local timezone when the platform fails.
    }

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(settings: settings);
    _initialized = true;
  }

  Future<bool> requestPermission() async {
    await initialize();
    final android = await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    final ios = await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    return (android ?? true) && (ios ?? true);
  }

  Future<void> cancelAll() async {
    await initialize();
    await _plugin.cancel(id: trainingReminderId);
    await _plugin.cancel(id: inactivityReminderId);
  }

  Future<void> schedule({
    required int hour,
    required int minute,
    required DateTime? lastTraining,
  }) async {
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      throw ArgumentError('Invalid notification time.');
    }
    await initialize();
    await cancelAll();

    final now = tz.TZDateTime.now(tz.local);
    var daily = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!daily.isAfter(now)) daily = daily.add(const Duration(days: 1));

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        'Lembretes do Vero',
        channelDescription: 'Lembretes de treino escolhidos por voce.',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
      iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
    );
    await _plugin.zonedSchedule(
      id: trainingReminderId,
      title: 'Um momento para voce',
      body: 'Seu proximo treino pode caber no seu ritmo de hoje.',
      scheduledDate: daily,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    if (lastTraining != null) {
      var inactiveAt = tz.TZDateTime.from(
        lastTraining.add(const Duration(days: 7)),
        tz.local,
      );
      if (!inactiveAt.isAfter(now)) {
        inactiveAt = now.add(const Duration(minutes: 1));
      }
      await _plugin.zonedSchedule(
        id: inactivityReminderId,
        title: 'Tudo bem voltar com calma',
        body:
            'Faz alguns dias desde seu ultimo treino. Quando quiser, o Vero esta aqui.',
        scheduledDate: inactiveAt,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }
}
