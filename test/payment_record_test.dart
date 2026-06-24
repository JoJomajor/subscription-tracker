import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:subscription_tracker/database/database_helper.dart';
import 'package:subscription_tracker/models/payment_record.dart';
import 'package:subscription_tracker/models/subscription.dart';
import 'package:subscription_tracker/providers/subscription_provider.dart';

void main() {
  // Инициализируем sqflite для тестов
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late DatabaseHelper dbHelper;
  late SubscriptionProvider provider;

  // Перед каждым тестом создаём чистую in-memory БД
  setUp(() async {
    dbHelper = DatabaseHelper.forTesting(databasePath: ':memory:');
    provider = SubscriptionProvider.forTesting(dbHelper);
  });

  // После каждого теста закрываем БД
  tearDown(() async {
    await dbHelper.close();
  });

  group('PaymentRecord Model Tests', () {
    
    test('Создание PaymentRecord', () {
      final record = PaymentRecord(
        subscriptionId: 1,
        paymentDate: DateTime(2025, 1, 15),
        amount: 500,
      );

      expect(record.subscriptionId, 1);
      expect(record.paymentDate, DateTime(2025, 1, 15));
      expect(record.amount, 500);
    });

    test('toMap и fromMap работают корректно', () {
      final record = PaymentRecord(
        id: 1,
        subscriptionId: 5,
        paymentDate: DateTime(2025, 6, 20),
        amount: 1200.50,
      );

      final map = record.toMap();
      final restored = PaymentRecord.fromMap(map);

      expect(restored.id, 1);
      expect(restored.subscriptionId, 5);
      expect(restored.amount, 1200.50);
      expect(restored.paymentDate.year, 2025);
      expect(restored.paymentDate.month, 6);
      expect(restored.paymentDate.day, 20);
    });
  });

  group('Payment Record Integration Tests', () {
    
    test('recordPayment создаёт запись об оплате', () async {
      // Добавляем подписку
      final sub = Subscription(
        name: 'Netflix',
        price: 500,
        currency: '₽',
        cycle: BillingCycle.monthly,
        startDate: DateTime(2025, 1, 1),
        category: 'Видео',
      );
      await provider.addSubscription(sub);

      final subscriptionId = provider.subscriptions.first.id!;

      // Записываем оплату
      await provider.recordPayment(subscriptionId);

      // Проверяем, что история не пустая
      final history = await provider.getPaymentHistory(subscriptionId);
      expect(history.length, 1);
      expect(history.first.amount, 500);
      expect(history.first.subscriptionId, subscriptionId);
    });

    test('recordPayment обновляет startDate подписки', () async {
      // Добавляем подписку с датой оплаты в прошлом
      final originalDate = DateTime.now().subtract(const Duration(days: 5));
      final sub = Subscription(
        name: 'Spotify',
        price: 200,
        currency: '₽',
        cycle: BillingCycle.monthly,
        startDate: originalDate,
        category: 'Музыка',
      );
      await provider.addSubscription(sub);

      final subscriptionId = provider.subscriptions.first.id!;

      // Записываем оплату
      await provider.recordPayment(subscriptionId);

      // Проверяем, что startDate обновился на следующую дату
      final updatedSub = await provider.getSubscriptionById(subscriptionId);
      expect(updatedSub!.startDate, isNot(equals(originalDate)));
      
      // Новая дата должна быть через месяц от оригинальной
      final expectedDate = DateTime(
        originalDate.year,
        originalDate.month + 1,
        originalDate.day,
      );
      expect(updatedSub.startDate.year, expectedDate.year);
      expect(updatedSub.startDate.month, expectedDate.month);
      expect(updatedSub.startDate.day, expectedDate.day);
    });

    test('getPaymentHistory возвращает историю в правильном порядке', () async {
      // Добавляем подписку
      final sub = Subscription(
        name: 'YouTube',
        price: 300,
        currency: '₽',
        cycle: BillingCycle.monthly,
        startDate: DateTime(2025, 1, 1),
        category: 'Видео',
      );
      await provider.addSubscription(sub);

      final subscriptionId = provider.subscriptions.first.id!;

      // Записываем несколько оплат
      await provider.recordPayment(subscriptionId);
      await Future.delayed(const Duration(milliseconds: 10));
      await provider.recordPayment(subscriptionId);
      await Future.delayed(const Duration(milliseconds: 10));
      await provider.recordPayment(subscriptionId);

      final history = await provider.getPaymentHistory(subscriptionId);
      
      // История должна быть отсортирована по убыванию даты
      expect(history.length, 3);
      expect(history[0].paymentDate.isAfter(history[1].paymentDate), true);
      expect(history[1].paymentDate.isAfter(history[2].paymentDate), true);
    });

    test('Множественные оплаты одной подписки', () async {
      final sub = Subscription(
        name: 'Test',
        price: 100,
        currency: '₽',
        cycle: BillingCycle.monthly,
        startDate: DateTime(2025, 1, 1),
        category: 'Тест',
      );
      await provider.addSubscription(sub);

      final subscriptionId = provider.subscriptions.first.id!;

      // Записываем 5 оплат
      for (int i = 0; i < 5; i++) {
        await provider.recordPayment(subscriptionId);
      }

      final history = await provider.getPaymentHistory(subscriptionId);
      expect(history.length, 5);
      
      // Все суммы должны быть одинаковыми
      for (final record in history) {
        expect(record.amount, 100);
      }
    });

    test('История оплат для разных подписок не пересекается', () async {
      // Добавляем две подписки
      final sub1 = Subscription(
        name: 'Sub1',
        price: 100,
        currency: '₽',
        cycle: BillingCycle.monthly,
        startDate: DateTime(2025, 1, 1),
        category: 'Тест',
      );
      final sub2 = Subscription(
        name: 'Sub2',
        price: 200,
        currency: '₽',
        cycle: BillingCycle.monthly,
        startDate: DateTime(2025, 1, 1),
        category: 'Тест',
      );
      await provider.addSubscription(sub1);
      await provider.addSubscription(sub2);

      final id1 = provider.subscriptions[0].id!;
      final id2 = provider.subscriptions[1].id!;

      // Записываем оплаты только для первой подписки
      await provider.recordPayment(id1);
      await provider.recordPayment(id1);

      // Проверяем историю
      final history1 = await provider.getPaymentHistory(id1);
      final history2 = await provider.getPaymentHistory(id2);

      expect(history1.length, 2);
      expect(history2.length, 0);  // У второй подписки нет истории
    });
  });
}