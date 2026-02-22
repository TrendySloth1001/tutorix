/// A billing invoice for a subscription payment event.
class InvoiceModel {
  final String id;
  final String subscriptionId;
  final String? razorpayPaymentId;
  final int amountPaise;
  final int totalPaise;
  final String currency;
  final int taxPaise;

  final String status; // PAID, FAILED, REFUNDED, PENDING
  final String type; // INITIAL, RENEWAL, UPGRADE, REFUND

  final String? invoiceNumber;
  final DateTime? paidAt;
  final DateTime? failedAt;

  final String? planSlug;
  final String? billingCycle;
  final String? notes;

  final DateTime createdAt;

  const InvoiceModel({
    required this.id,
    required this.subscriptionId,
    this.razorpayPaymentId,
    required this.amountPaise,
    required this.totalPaise,
    this.currency = 'INR',
    this.taxPaise = 0,
    required this.status,
    required this.type,
    this.invoiceNumber,
    this.paidAt,
    this.failedAt,
    this.planSlug,
    this.billingCycle,
    this.notes,
    required this.createdAt,
  });

  bool get isPaid => status == 'PAID';
  bool get isFailed => status == 'FAILED';

  double get amountRupees => amountPaise / 100;
  double get totalRupees => totalPaise / 100;
  double get taxRupees => taxPaise / 100;

  factory InvoiceModel.fromJson(Map<String, dynamic> json) {
    return InvoiceModel(
      id: json['id'] as String,
      subscriptionId: json['subscriptionId'] as String,
      razorpayPaymentId: json['razorpayPaymentId'] as String?,
      amountPaise: (json['amountPaise'] as num?)?.toInt() ?? 0,
      totalPaise: (json['totalPaise'] as num?)?.toInt() ?? 0,
      currency: json['currency'] as String? ?? 'INR',
      taxPaise: (json['taxPaise'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'PENDING',
      type: json['type'] as String? ?? 'RENEWAL',
      invoiceNumber: json['invoiceNumber'] as String?,
      paidAt: json['paidAt'] != null
          ? DateTime.parse(json['paidAt'] as String)
          : null,
      failedAt: json['failedAt'] != null
          ? DateTime.parse(json['failedAt'] as String)
          : null,
      planSlug: json['planSlug'] as String?,
      billingCycle: json['billingCycle'] as String?,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
