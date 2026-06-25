import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:subscription_tracker/database/database_helper.dart';
import 'package:subscription_tracker/providers/subscription_provider.dart';
import 'package:subscription_tracker/models/subscription.dart';

void main() {
  // Инициализируем sqflite для тестов
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late DatabaseHelper dbHelper;
  late SubscriptionProvider provider;

  // Перед КАЖДЫМ тестом создаём НОВУЮ in-memory базу
  setUp(() async {
    dbHelper = DatabaseHelper.forTesting(databasePath: ':memory:');
    provider = SubscriptionProvider.forTesting(dbHelper);
  });

  // После каждого теста закрываем БД
  tearDown(() async {
    await dbHelper.close();
  });

  group('SubscriptionProvider Tests', () {
    
    test('Начальное состояние пустое', () {
      expect(provider.subscriptions, isEmpty);
      expect(provider.totalMonthlySpending, 0.0);
    });

    test('Добавление подписки', () async {
      final sub = Subscription(
        name: 'Netflix',
        price: 500,
        currency: '₽',
        cycle: BillingCycle.monthly,
        startDate: DateTime(2025, 1, 1),
        category: 'Видео',
      );

      await provider.addSubscription(sub);
      
      expect(provider.subscriptions.length, 1);
      expect(provider.subscriptions.first.name, 'Netflix');
    });

    test('Подсчёт общей суммы', () async {
      // Создаём подписки с датой в БУДУЩЕМ (не просроченные)
      await provider.addSubscription(Subscription(
        name: 'Sub1', 
        price: 200, 
        currency: '₽',
        cycle: BillingCycle.monthly, 
        startDate: DateTime.now().add(const Duration(days: 5)), // ← 5 дней в будущем
        category: 'Test',
      ));
      await provider.addSubscription(Subscription(
        name: 'Sub2', 
        price: 300, 
        currency: '₽',
        cycle: BillingCycle.monthly, 
        startDate: DateTime.now().add(const Duration(days: 10)), // ← 10 дней в будущем
        category: 'Test',
      ));

      expect(provider.totalMonthlySpending, 500);
      expect(provider.totalYearlySpending, 6000);
    });

    test('Удаление подписки', () async {
      final sub = Subscription(
        name: 'Test',
        price: 100,
        currency: '₽',
        cycle: BillingCycle.monthly,
        startDate: DateTime(2025, 1, 1),
        category: 'Тест',
      );
      
      await provider.addSubscription(sub);
      expect(provider.subscriptions.length, 1);

      final id = provider.subscriptions.first.id!;
      await provider.deleteSubscription(id);
      
      expect(provider.subscriptions, isEmpty);
    });

    test('Поиск по названию', () async {
      await provider.addSubscription(Subscription(
        name: 'Netflix', price: 500, currency: '₽',
        cycle: BillingCycle.monthly, startDate: DateTime.now(), category: 'Видео',
      ));
      await provider.addSubscription(Subscription(
        name: 'Spotify', price: 200, currency: '₽',
        cycle: BillingCycle.monthly, startDate: DateTime.now(), category: 'Музыка',
      ));

      final results = provider.searchByName('net');
      expect(results.length, 1);
      expect(results.first.name, 'Netflix');
    });

    test('Фильтрация по категории', () async {
      await provider.addSubscription(Subscription(
        name: 'Netflix', price: 500, currency: '₽',
        cycle: BillingCycle.monthly, startDate: DateTime.now(), category: 'Видео',
      ));
      await provider.addSubscription(Subscription(
        name: 'Spotify', price: 200, currency: '₽',
        cycle: BillingCycle.monthly, startDate: DateTime.now(), category: 'Музыка',
      ));

      final videoSubs = provider.filterByCategory('Видео');
      expect(videoSubs.length, 1);
      expect(videoSubs.first.name, 'Netflix');
    });

    test('Получение всех категорий', () async {
      await provider.addSubscription(Subscription(
        name: 'Netflix', price: 500, currency: '₽',
        cycle: BillingCycle.monthly, startDate: DateTime.now(), category: 'Видео',
      ));
      await provider.addSubscription(Subscription(
        name: 'Spotify', price: 200, currency: '₽',
        cycle: BillingCycle.monthly, startDate: DateTime.now(), category: 'Музыка',
      ));
      await provider.addSubscription(Subscription(
        name: 'YouTube', price: 300, currency: '₽',
        cycle: BillingCycle.monthly, startDate: DateTime.now(), category: 'Видео',
      ));

      final categories = provider.allCategories;
      expect(categories.length, 2);
      expect(categories, contains('Видео'));
      expect(categories, contains('Музыка'));
    });

    test('Просроченная подписка определяется автоматически', () async {
      // Подписка с датой оплаты в прошлом
      final overdueSub = Subscription(
        name: 'Test',
        price: 100,
        currency: '₽',
        cycle: BillingCycle.monthly,
        startDate: DateTime.now().subtract(const Duration(days: 5)), // 5 дней назад
        category: 'Тест',
      );
      await provider.addSubscription(overdueSub);

      expect(provider.overdueSubscriptions.length, 1);
      expect(provider.activeSubscriptions.length, 0);
      expect(provider.overdueSubscriptions.first.isOverdue, true);
    });
  });
}