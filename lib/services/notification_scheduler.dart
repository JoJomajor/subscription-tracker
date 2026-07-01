import '../models/subscription.dart';
import 'notification_service.dart';

class NotificationScheduler {
  static final NotificationService _notificationService = NotificationService();

  // Вычислить время уведомления (за 24 часа до nextBillingDate)
  static DateTime _calculateNotificationTime(DateTime billingDate) {
    return billingDate.subtract(const Duration(hours: 24));
  }

  // Запланировать уведомление для подписки
  static Future<void> scheduleForSubscription(Subscription subscription) async {
    // Не планируем для неактивных подписок
    if (!subscription.isActive) {
      print('⏸️ Подписка "${subscription.name}" неактивна — уведомление не запланировано');
      return;
    }

    // Вычисляем время уведомления
    final notificationTime = _calculateNotificationTime(subscription.nextBillingDate);

    // Если время уже прошло — не планируем
    if (notificationTime.isBefore(DateTime.now())) {
      print('⏰ Время уведомления уже прошло для "${subscription.name}"');
      return;
    }

    // Формируем текст уведомления
    final title = '🔔 Напоминание о подписке';
    final body = 'Завтра будет списание за ${subscription.name} '
        '(${subscription.price.toStringAsFixed(0)} ${subscription.currency})';

    // ID уведомления = ID подписки (чтобы можно было отменить при обновлении)
    final notificationId = subscription.id ?? subscription.name.hashCode;

    await _notificationService.scheduleNotification(
      id: notificationId,
      title: title,
      body: body,
      scheduledDate: notificationTime,
      payload: subscription.id?.toString(),
    );
  }

  // Отменить уведомление для подписки
  static Future<void> cancelForSubscription(Subscription subscription) async {
    final notificationId = subscription.id ?? subscription.name.hashCode;
    await _notificationService.cancelNotification(notificationId);
  }

  // Перепланировать уведомление (отменить старое + запланировать новое)
  static Future<void> rescheduleForSubscription(Subscription subscription) async {
    await cancelForSubscription(subscription);
    await scheduleForSubscription(subscription);
  }
}