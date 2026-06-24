import 'package:flutter/foundation.dart';
import '../models/subscription.dart';
import '../models/payment_record.dart';
import '../database/database_helper.dart';

class SubscriptionProvider extends ChangeNotifier {
  final DatabaseHelper _dbHelper;
  
  // Основной конструктор (для приложения)
  SubscriptionProvider() : _dbHelper = DatabaseHelper();
  
  // Конструктор для тестов (с инъекцией DatabaseHelper)
  SubscriptionProvider.forTesting(this._dbHelper);
  
  List<Subscription> _subscriptions = [];
  List<Subscription> get subscriptions => _subscriptions;
  
  List<Subscription> get activeSubscriptions => 
    _subscriptions.where((sub) => sub.isActive && !sub.isOverdue).toList();

  List<Subscription> get overdueSubscriptions => 
    _subscriptions.where((sub) => sub.isOverdue).toList();  
  
  double get totalMonthlySpending => 
      activeSubscriptions.fold<double>(0.0, (sum, sub) => sum + sub.monthlyPrice);
  
  double get totalYearlySpending => totalMonthlySpending * 12;
  
  Future<void> loadSubscriptions() async {
    _subscriptions = await _dbHelper.getAllSubscriptions();
    notifyListeners();
  }
  
  Future<void> addSubscription(Subscription subscription) async {
    await _dbHelper.insertSubscription(subscription);
    await loadSubscriptions();
  }
  
  Future<void> updateSubscription(Subscription subscription) async {
    await _dbHelper.updateSubscription(subscription);
    await loadSubscriptions();
  }
  
  Future<void> deleteSubscription(int id) async {
    await _dbHelper.deleteSubscription(id);
    await loadSubscriptions();
  }
  
  Future<Subscription?> getSubscriptionById(int id) async {
    return await _dbHelper.getSubscriptionById(id);
  }
  
  Future<double> calculateTotalMonthlySpending() async {
    return await _dbHelper.getTotalMonthlySpending();
  }
  
  List<Subscription> filterByCategory(String category) {
    return _subscriptions.where((sub) => sub.category == category).toList();
  }
  
  List<Subscription> searchByName(String query) {
    if (query.isEmpty) return _subscriptions;
    
    final lowerQuery = query.toLowerCase();
    return _subscriptions.where((sub) => 
        sub.name.toLowerCase().contains(lowerQuery)
    ).toList();
  }
  
  List<String> get allCategories {
    final categories = _subscriptions.map((sub) => sub.category).toSet();
    return categories.toList()..sort();
  }

  // Метод оплаты подписки
  Future<void> recordPayment(int subscriptionId) async {
    final subscription = await getSubscriptionById(subscriptionId);
    if (subscription == null) return;

    // 1. Создаём запись об оплате
    final paymentRecord = PaymentRecord(
      subscriptionId: subscriptionId,
      paymentDate: DateTime.now(),
      amount: subscription.price,
    );
    await _dbHelper.insertPaymentRecord(paymentRecord);

    // 2. Обновляем startDate на следующую дату оплаты
    final updatedSubscription = subscription.pay();
    await updateSubscription(updatedSubscription);
  }

  // Получить историю оплат для подписки
  Future<List<PaymentRecord>> getPaymentHistory(int subscriptionId) async {
    return await _dbHelper.getPaymentHistory(subscriptionId);
  }
}