import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  // Канал уведомлений
  static const String channelId = 'subscription_reminders';
  static const String channelName = 'Напоминания о подписках';
  static const String channelDescription = 'Уведомления за 24 часа до оплаты';

  // Инициализация сервиса уведомлений
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Инициализируем базу данных часовых поясов
    tz_data.initializeTimeZones();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        print('Notification tapped: ${response.payload}');
      },
    );

    _isInitialized = true;
  }

  // Создание канала уведомлений (для Android 8+)
  Future<void> _ensureChannelExists() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      channelId,
      channelName,
      description: channelDescription,
      importance: Importance.high,
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  // Отправка мгновенного уведомления (для тестов)
  Future<void> sendNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    await _ensureChannelExists();

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000, // Уникальный ID
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  // ПЛАНИРОВАНИЕ уведомления на конкретную дату и время
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    await _ensureChannelExists();

    // Проверяем, что дата не в прошлом
    if (scheduledDate.isBefore(DateTime.now())) {
      print('⚠️ Дата уведомления в прошлом: $scheduledDate');
      return;
    }

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidDetails);

    // Планируем с точным временем (requires SCHEDULE_EXACT_ALARM permission)
    await _notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );

    print('✅ Уведомление #$id запланировано на: $scheduledDate');
  }

  // Отмена конкретного уведомления по ID
  Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
    print('🗑️ Уведомление #$id отменено');
  }

  // Отмена всех уведомлений
  Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
  }
}