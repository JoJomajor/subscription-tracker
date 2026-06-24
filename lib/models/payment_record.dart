// lib/models/payment_record.dart

class PaymentRecord {
  final int? id;
  final int subscriptionId;  // ID подписки
  final DateTime paymentDate;  // Дата оплаты
  final double amount;  // Сумма оплаты

  PaymentRecord({
    this.id,
    required this.subscriptionId,
    required this.paymentDate,
    required this.amount,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'subscriptionId': subscriptionId,
      'paymentDate': paymentDate.toIso8601String(),
      'amount': amount,
    };
  }

  factory PaymentRecord.fromMap(Map<String, dynamic> map) {
    return PaymentRecord(
      id: map['id'],
      subscriptionId: map['subscriptionId'],
      paymentDate: DateTime.parse(map['paymentDate']),
      amount: map['amount'],
    );
  }
}