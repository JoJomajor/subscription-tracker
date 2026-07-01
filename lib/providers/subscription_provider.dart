import 'package:flutter/foundation.dart';
import '../models/subscription.dart';
import '../models/payment_record.dart';
import '../database/database_helper.dart';
import '../services/notification_scheduler.dart';

class SubscriptionProvider extends ChangeNotifier {
  final DatabaseHelper _dbHelper;
  
  SubscriptionProvider() : _dbHelper = DatabaseHelper();
  SubscriptionProvider.forTesting(this._dbHelper);
  
  List<Subscription> _subscriptions = [];
  List<Subscription> get subscriptions => _subscriptions;
  
  List<Subscription> get activeSubscriptions => 
      _subscriptions.where((sub) => sub.isActive && !sub.isOverdue).toList();

  List<Subscription> get overdueSubscriptions => 
      _subscriptions.where((sub) => sub.isActive && sub.isOverdue).toList();  
  
  double get totalMonthlySpending => 
      activeSubscriptions.fold<double>(0.0, (sum, sub) => sum + sub.monthlyPrice);
  
  double get totalYearlySpending => totalMonthlySpending * 12;
  
  Future<void> loadSubscriptions() async {
    _subscriptions = await _dbHelper.getAllSubscriptions();
    notifyListeners();
    
    // ✅ Перепланируем все уведомления при запуске приложения
    for (final sub in _subscriptions) {
      if (sub.isActive) {
        await NotificationScheduler.scheduleForSubscription(sub);
      }
    }
  }
  
  Future<void> addSubscription(Subscription subscription) async {
    final id = await _dbHelper.insertSubscription(subscription);
    final newSub = subscription.copyWith(id: id);
    
    _subscriptions.add(newSub);
    notifyListeners();
    
    // ✅ ПЛАНИРУЕМ УВЕДОМЛЕНИЕ для новой подписки
    await NotificationScheduler.scheduleForSubscription(newSub);
  }
  
  Future<void> updateSubscription(Subscription subscription) async {
    await _dbHelper.updateSubscription(subscription);
    final index = _subscriptions.indexWhere((s) => s.id == subscription.id);
    if (index != -1) {
      _subscriptions[index] = subscription;
      notifyListeners();
    }
    
    // ✅ ПЕРЕПЛАНИРУЕМ УВЕДОМЛЕНИЕ при изменении подписки
    await NotificationScheduler.rescheduleForSubscription(subscription);
  }
  
  Future<void> deleteSubscription(int id) async {
    // Находим подписку перед удалением
    final sub = _subscriptions.firstWhere((s) => s.id == id);
    
    await _dbHelper.deleteSubscription(id);
    _subscriptions.removeWhere((s) => s.id == id);
    notifyListeners();
    
    // ✅ ОТМЕНЯЕМ УВЕДОМЛЕНИЕ при удалении подписки
    await NotificationScheduler.cancelForSubscription(sub);
  }
  
  Future<Subscription?> getSubscriptionById(int id) async {
    return await _dbHelper.getSubscriptionById(id);
  }

  List<Subscription> filterByCategory(String category) {
    return _subscriptions.where((sub) => sub.category == category).toList();
  }
  
  List<Subscription> searchByName(String query) {
    if (query.isEmpty) return _subscriptions;
    final lowerQuery = query.toLowerCase();
    return _subscriptions.where((sub) => sub.name.toLowerCase().contains(lowerQuery)).toList();
  }
  
  List<String> get allCategories {
    final categories = _subscriptions.map((sub) => sub.category).toSet();
    return categories.toList()..sort();
  }

  Future<void> recordPayment(int subscriptionId) async {
    final subscription = await getSubscriptionById(subscriptionId);
    if (subscription == null) return;
    
    final paymentRecord = PaymentRecord(
      subscriptionId: subscriptionId,
      paymentDate: DateTime.now(),
      amount: subscription.price,
    );
    await _dbHelper.insertPaymentRecord(paymentRecord);
    
    // Продлеваем подписку — updateSubscription автоматически перепланирует уведомление
    await updateSubscription(subscription.pay());
  }

  Future<List<PaymentRecord>> getPaymentHistory(int subscriptionId) async {
    return await _dbHelper.getPaymentHistory(subscriptionId);
  }
}