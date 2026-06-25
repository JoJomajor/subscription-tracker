enum BillingCycle {
  weekly,
  monthly,
  yearly,
}

class Subscription {
  final int? id;
  final String name;
  final double price;
  final String currency;
  final BillingCycle cycle;
  final DateTime startDate;
  final DateTime nextBillingDate; // ✅ НОВОЕ
  final String category;
  final bool isActive;
  final String? iconPath;

  Subscription({
    this.id,
    required this.name,
    required this.price,
    required this.currency,
    required this.cycle,
    required this.startDate,
    required this.nextBillingDate, // ✅
    required this.category,
    this.isActive = true,
    this.iconPath,
  });

  Subscription copyWith({
  int? id,
  String? name,
  double? price,
  String? category,
  BillingCycle? cycle,
  DateTime? startDate,
  DateTime? nextBillingDate,
  bool? isActive,
  String? iconPath,
}) {
  return Subscription(
    id: id ?? this.id, // ✅ ВАЖНО
    name: name ?? this.name,
    price: price ?? this.price,
    category: category ?? this.category,
    cycle: cycle ?? this.cycle,
    startDate: startDate ?? this.startDate,
    nextBillingDate: nextBillingDate ?? this.nextBillingDate,
    isActive: isActive ?? this.isActive,
    iconPath: iconPath ?? this.iconPath,
    currency: this.currency,
  );
}

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'currency': currency,
      'cycle': cycle.index,
      'startDate': startDate.toIso8601String(),
      'nextBillingDate': nextBillingDate.toIso8601String(), // ✅
      'category': category,
      'isActive': isActive ? 1 : 0,
      'iconPath': iconPath,
    };
  }

  factory Subscription.fromMap(Map<String, dynamic> map) {
    return Subscription(
      id: map['id'],
      name: map['name'],
      price: map['price'],
      currency: map['currency'],
      cycle: BillingCycle.values[map['cycle']],
      startDate: DateTime.parse(map['startDate']),
      nextBillingDate: DateTime.parse(map['nextBillingDate']), // ✅
      category: map['category'],
      isActive: map['isActive'] == 1,
      iconPath: map['iconPath'],
    );
  }
  
  bool get isOverdue => isActive && nextBillingDate.isBefore(DateTime.now());

  // ✅ правильная логика оплаты
  Subscription pay() {
    DateTime newNext;
    switch (cycle) {
      case BillingCycle.weekly:
        newNext = nextBillingDate.add(const Duration(days: 7));
        break;
      case BillingCycle.monthly:
        newNext = DateTime(nextBillingDate.year, nextBillingDate.month + 1, nextBillingDate.day);
        break;
      case BillingCycle.yearly:
        newNext = DateTime(nextBillingDate.year + 1, nextBillingDate.month, nextBillingDate.day);
        break;
    }

    return copyWith(
      startDate: nextBillingDate,
      nextBillingDate: newNext,
    );
  }
  double get monthlyPrice {
  switch (cycle) {
    case BillingCycle.weekly:
      return price * 4.33;
    case BillingCycle.monthly:
      return price;
    case BillingCycle.yearly:
      return price / 12;
  }
}
}