import 'package:flutter_test/flutter_test.dart';
import 'package:subscription_tracker/models/subscription.dart';

void main() {
  group('Subscription Model Tests', () {
    
    test('Создание подписки', () {
      final sub = Subscription(
        name: 'Netflix',
        price: 500,
        currency: '₽',
        cycle: BillingCycle.monthly,
        startDate: DateTime(2025, 1, 1),
        category: 'Видео',
      );

      expect(sub.name, 'Netflix');
      expect(sub.price, 500);
      expect(sub.currency, '₽');
      expect(sub.cycle, BillingCycle.monthly);
      expect(sub.isActive, true);
    });

    test('copyWith работает', () {
      final sub = Subscription(
        name: 'Netflix',
        price: 500,
        currency: '₽',
        cycle: BillingCycle.monthly,
        startDate: DateTime(2025, 1, 1),
        category: 'Видео',
      );

      final updated = sub.copyWith(price: 600);
      
      expect(updated.price, 600);
      expect(updated.name, 'Netflix');  // не изменилось
      expect(updated.currency, '₽');    // не изменилось
    });

    test('monthlyPrice для разных циклов', () {
      // Ежемесячная
      final monthly = Subscription(
        name: 'Spotify',
        price: 200,
        currency: '₽',
        cycle: BillingCycle.monthly,
        startDate: DateTime(2025, 1, 1),
        category: 'Музыка',
      );
      expect(monthly.monthlyPrice, 200);

      // Ежегодная
      final yearly = Subscription(
        name: 'YouTube Premium',
        price: 2400,
        currency: '₽',
        cycle: BillingCycle.yearly,
        startDate: DateTime(2025, 1, 1),
        category: 'Видео',
      );
      expect(yearly.monthlyPrice, 200);  // 2400 / 12 = 200

      // Еженедельная
      final weekly = Subscription(
        name: 'Test',
        price: 100,
        currency: '₽',
        cycle: BillingCycle.weekly,
        startDate: DateTime(2025, 1, 1),
        category: 'Тест',
      );
      expect(weekly.monthlyPrice, closeTo(433, 1));  // 100 * 4.33 ≈ 433
    });

    test('toMap и fromMap работают', () {
      final sub = Subscription(
        id: 1,
        name: 'Netflix',
        price: 500,
        currency: '₽',
        cycle: BillingCycle.monthly,
        startDate: DateTime(2025, 1, 1),
        category: 'Видео',
        isActive: true,
      );

      final map = sub.toMap();
      final restored = Subscription.fromMap(map);

      expect(restored.id, 1);
      expect(restored.name, 'Netflix');
      expect(restored.price, 500);
      expect(restored.cycle, BillingCycle.monthly);
    });
  });
}