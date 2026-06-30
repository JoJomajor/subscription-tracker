import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';

class SubscriptionNotificationService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Инициализация сервиса (вызывать один раз при старте приложения)
  Future<void> init() async {
    await _configureLocalTimeZone();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@drawable/ic_notification'); // Ваша иконка

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Обработка нажатия на уведомление (например, открыть экран подписки)
        // final payload = response.payload;
      },
    );
  }

  // Запрос разрешения на уведомления (для Android 13+)
  Future<bool> requestNotificationPermission() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  // Настройка часового пояса
  Future<void> _configureLocalTimeZone() async {
    tz.initializeTimeZones();
    final String timeZoneName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timeZoneName));
  }

  /// Планирует напоминание о списании средств
  /// [subscriptionId] - ID подписки (используется как ID уведомления, чтобы можно было его отменить/обновить)
  /// [serviceName] - Название (например, "Яндекс Плюс")
  /// [amount] - Сумма (например, "299 ₽")
  /// [renewalDate] - Дата следующего списания
  /// [remindDaysBefore] - За сколько дней напомнить (по умолчанию 1 день)
  Future<void> scheduleSubscriptionReminder({
    required int subscriptionId,
    required String serviceName,
    required String amount,
    required DateTime renewalDate,
    int remindDaysBefore = 1,
  }) async {
    // Вычисляем дату напоминания (например, за 1 день до списания в 10:00 утра)
    DateTime reminderDate = renewalDate.subtract(Duration(days: remindDaysBefore));
    reminderDate = DateTime(
      reminderDate.year,
      reminderDate.month,
      reminderDate.day,
      10, // 10 утра
      0,
    );

    // Если дата напоминания уже в прошлом, не планируем
    if (reminderDate.isBefore(DateTime.now())) return;

    final tz.TZDateTime scheduledDate = tz.TZDateTime.from(reminderDate, tz.local);

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'subscription_channel_id', // ID канала
      'Напоминания о подписках', // Название канала
      channelDescription: 'Уведомления о предстоящих списаниях средств',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _notificationsPlugin.zonedSchedule(
      subscriptionId, // Уникальный ID уведомления (равен ID подписки в БД)
      'Списание средств: $serviceName',
      'Завтра будет списано $amount. Проверьте баланс!',
      scheduledDate,
      platformChannelSpecifics,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: null, // Одноразовое уведомление
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle, // КРИТИЧНО для точности!
      payload: 'subscription_$subscriptionId',
    );
  }

  // Отмена напоминания (если пользователь удалил подписку)
  Future<void> cancelSubscriptionReminder(int subscriptionId) async {
    await _notificationsPlugin.cancel(subscriptionId);
  }

  // Отмена всех напоминаний
  Future<void> cancelAll() async {
    await _notificationsPlugin.cancelAll();
  }
}