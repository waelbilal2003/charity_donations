// نموذج لمعاملة دفع واحدة (صف واحد في الجدول)
class PaymentTransaction {
  final String serialNumber;
  final String paymentValue;
  final String workerName;
  final String notes;

  PaymentTransaction({
    required this.serialNumber,
    required this.paymentValue,
    required this.workerName,
    required this.notes,
  });

  factory PaymentTransaction.fromJson(Map<String, dynamic> json) {
    return PaymentTransaction(
      serialNumber: json['serialNumber'] ?? '',
      paymentValue: json['paymentValue'] ?? '0.00',
      workerName: json['workerName'] ?? '',
      notes: json['notes'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'serialNumber': serialNumber,
      'paymentValue': paymentValue,
      'workerName': workerName,
      'notes': notes,
    };
  }
}

// نموذج لمستند الدفعات الكامل ليوم واحد
class PaymentDocument {
  final String date;
  final List<PaymentTransaction> transactions;
  final Map<String, String> totals;

  PaymentDocument({
    required this.date,
    required this.transactions,
    required this.totals,
  });

  factory PaymentDocument.fromJson(Map<String, dynamic> json) {
    var transactionsList = json['transactions'] as List;
    List<PaymentTransaction> transactions =
        transactionsList.map((i) => PaymentTransaction.fromJson(i)).toList();

    return PaymentDocument(
      date: json['date'] ?? '',
      transactions: transactions,
      totals: Map<String, String>.from(json['totals'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'transactions': transactions.map((t) => t.toJson()).toList(),
      'totals': totals,
    };
  }
}
