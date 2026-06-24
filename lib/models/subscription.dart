

enum BillingCycle {
  weekly,
  monthly,
  yearly,
}

//Класс модели подписки
class Subscription 
{
final int? id;                // ID в БД
final String name;            // Название сервиса
final double price;           // Цена
final String currency;        // Валюта 
final BillingCycle cycle;     // Цикл оплаты (еженедельно/ежемесячно/ежегодно)
final DateTime startDate;     // Дата начала
final String category;        // Категория
final bool isActive;          // Активна ли

//Конструктор
Subscription({
  this.id,
  required this.name,
  required this.price,
  required this.currency,
  required this.cycle,
  required this.startDate,
  required this.category,
  this.isActive = true,
});

//Метод для копирования с изменениями
Subscription copyWith({
  int? id,
  String? name,
  double? price,
  String? currency,
  BillingCycle? cycle,
  DateTime? startDate,
  String? category,
  bool? isActive,
}){
  return Subscription(
    id: id ?? this.id,
    name: name ?? this.name,
    price: price ?? this.price,
    currency: currency ?? this.currency,
    cycle: cycle ?? this.cycle,
    startDate: startDate ?? this.startDate,
    category: category ?? this.category,
    isActive: isActive ?? this.isActive,
  );
}

//Преобразование в Map (для сохранения в БД)
Map<String, dynamic> toMap() {
  return {
      'id': id,
      'name': name,
      'price': price,
      'currency': currency,
      'cycle': cycle.index,  // сохраняем как число (0, 1, 2)
      'startDate': startDate.toIso8601String(),  // дата как строка
      'category': category,
      'isActive': isActive ? 1 : 0,  // SQLite не любит bool
    };
}

//Создание из Map (для чтения из БД)
factory Subscription.fromMap(Map<String, dynamic> map)
{
  return Subscription(
      id: map['id'],
      name: map['name'],
      price: map['price'],
      currency: map['currency'],
      cycle: BillingCycle.values[map['cycle']],
      startDate: DateTime.parse(map['startDate']),
      category: map['category'],
      isActive: map['isActive'] == 1,
    );
}

//Вычисление месячной стоимости
double get monthlyPrice {
switch (cycle) {
      case BillingCycle.weekly:
        return price * 4.33;  // в месяце ~4.33 недели
      case BillingCycle.monthly:
        return price;
      case BillingCycle.yearly:
        return price / 12;
} 
}

//Вычисление годовой стоимости
double get yearlyPrice => monthlyPrice * 12;

//Дата следующего списания
DateTime get nextBillingDate {
    final now = DateTime.now();
    switch (cycle) {
      case BillingCycle.weekly:
        return startDate.add(Duration(days: 7 * ((now.difference(startDate).inDays ~/ 7) + 1)));
      case BillingCycle.monthly:
        return DateTime(startDate.year, startDate.month + ((now.month - startDate.month) ~/ 1) + 1, startDate.day);
      case BillingCycle.yearly:
        return DateTime(startDate.year + ((now.year - startDate.year) ~/ 1) + 1, startDate.month, startDate.day);
    }
  }

// Подписка просрочена, если дата оплаты прошла
bool get isOverdue => isActive && startDate.isBefore(DateTime.now());

// Метод для оплаты: возвращает новую подписку с обновлённой датой
Subscription pay() {
  DateTime nextDate;
  switch (cycle) {
    case BillingCycle.weekly:
      nextDate = startDate.add(const Duration(days: 7));
      break;
    case BillingCycle.monthly:
      nextDate = DateTime(startDate.year, startDate.month + 1, startDate.day);
      break;
    case BillingCycle.yearly:
      nextDate = DateTime(startDate.year + 1, startDate.month, startDate.day);
      break;
  }
  return copyWith(startDate: nextDate);
}



}