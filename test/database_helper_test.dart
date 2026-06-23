import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:subscription_tracker/database/database_helper.dart';
import 'package:subscription_tracker/models/subscription.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late DatabaseHelper dbHelper;

  // Каждый тест использует свою in-memory БД
  setUp(() {
    dbHelper = DatabaseHelper.forTesting(databasePath: ':memory:');
  });

  tearDown(() async {
    await dbHelper.close();
  });

  group('Database Tests', () {
    
    test('Добавление подписки', () async {
      final sub = Subscription(
        name: 'Netflix',
        price: 500,
        currency: '₽',
        cycle: BillingCycle.monthly,
        startDate: DateTime(2025, 1, 1),
        category: 'Видео',
      );

      final id = await dbHelper.insertSubscription(sub);
      expect(id, isNotNull);
      expect(id, greaterThan(0));
    });

    test('Получение всех подписок', () async {
      final sub = Subscription(
        name: 'Spotify',
        price: 200,
        currency: '₽',
        cycle: BillingCycle.monthly,
        startDate: DateTime(2025, 1, 1),
        category: 'Музыка',
      );
      await dbHelper.insertSubscription(sub);

      final subscriptions = await dbHelper.getAllSubscriptions();
      expect(subscriptions, isNotEmpty);
      expect(subscriptions.any((s) => s.name == 'Spotify'), true);
    });

    test('Обновление подписки', () async {
      final sub = Subscription(
        name: 'YouTube',
        price: 300,
        currency: '₽',
        cycle: BillingCycle.monthly,
        startDate: DateTime(2025, 1, 1),
        category: 'Видео',
      );
      final id = await dbHelper.insertSubscription(sub);

      final updated = sub.copyWith(id: id, price: 400);
      await dbHelper.updateSubscription(updated);

      final fromDb = await dbHelper.getSubscriptionById(id);
      expect(fromDb?.price, 400);
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
      final id = await dbHelper.insertSubscription(sub);

      await dbHelper.deleteSubscription(id);

      final fromDb = await dbHelper.getSubscriptionById(id);
      expect(fromDb, isNull);
    });

    test('Подсчёт общей суммы', () async {
      await dbHelper.insertSubscription(Subscription(
        name: 'Sub1', price: 200, currency: '₽',
        cycle: BillingCycle.monthly, startDate: DateTime.now(), category: 'Test',
      ));
      await dbHelper.insertSubscription(Subscription(
        name: 'Sub2', price: 300, currency: '₽',
        cycle: BillingCycle.monthly, startDate: DateTime.now(), category: 'Test',
      ));

      final total = await dbHelper.getTotalMonthlySpending();
      expect(total, 500);
    });
  });
}