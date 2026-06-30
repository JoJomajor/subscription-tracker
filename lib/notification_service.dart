import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';

class SubscriptionNotificationService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    await _configureLocalTimeZone();

    // Используем стандартную иконку приложения (временно)
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        print('Пользователь нажал на уведомление: ${response.payload}');
      },
    );
  }

  Future<bool> requestNotificationPermission() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  Future<void> _configureLocalTimeZone() async {
    tz.initializeTimeZones();
    final String timeZoneName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timeZoneName));
  }

  Future<void> scheduleSubscriptionReminder({
    required int subscriptionId,
    required String serviceName,
    required String amount,
    required DateTime renewalDate,
    int remindDaysBefore = 1,
  }) async {
    DateTime reminderDate = renewalDate.subtract(Duration(days: remindDaysBefore));
    reminderDate = DateTime(
      reminderDate.year,
      reminderDate.month,
      reminderDate.day,
      10,
      0,
    );

    if (reminderDate.isBefore(DateTime.now())) return;

    final tz.TZDateTime scheduledDate = tz.TZDateTime.from(reminderDate, tz.local);

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'subscription_channel_id',
      'Напоминания о подписках',
      channelDescription: 'Уведомления о предстоящих списаниях средств',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _notificationsPlugin.zonedSchedule(
      subscriptionId,
      'Списание средств: $serviceName',
      'Завтра будет списано $amount. Проверьте баланс!',
      scheduledDate,
      platformChannelSpecifics,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: null,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: 'subscription_$subscriptionId',
    );
  }

  Future<void> cancelSubscriptionReminder(int subscriptionId) async {
    await _notificationsPlugin.cancel(subscriptionId);
  }

  Future<void> cancelAll() async {
    await _notificationsPlugin.cancelAll();
  }

  // Добавил метод для тестового уведомления
  Future<void> showTestNotification() async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'subscription_channel_id',
      'Напоминания о подписках',
      channelDescription: 'Уведомления о предстоящих списаниях',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      999,
      'Тестовое уведомление',
      'Если вы видите это — уведомления работают!',
      notificationDetails,
    );
  }
}