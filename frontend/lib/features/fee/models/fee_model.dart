/// A reusable fee template (e.g. "Monthly Tuition ₹2500").
class FeeStructureModel {
  final String id;
  final String coachingId;
  final String name;
  final String? description;
  final double amount;
  final String currency;
  final String
  cycle; // ONCE | MONTHLY | QUARTERLY | HALF_YEARLY | YEARLY | CUSTOM
  final double lateFinePerDay;
  final bool isActive;
  final int assignmentCount;
  final DateTime? createdAt;

  const FeeStructureModel({
    required this.id,
    required this.coachingId,
    required this.name,
    this.description,
    required this.amount,
    this.currency = 'INR',
    this.cycle = 'MONTHLY',
    this.lateFinePerDay = 0,
    this.isActive = true,
    this.assignmentCount = 0,
    this.createdAt,
  });

  factory FeeStructureModel.fromJson(Map<String, dynamic> json) {
    final count = json['_count'] as Map<String, dynamic>?;
    return FeeStructureModel(
      id: json['id'] as String,
      coachingId: json['coachingId'] as String? ?? '',
      name: json['name'] as String,
      description: json['description'] as String?,
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'INR',
      cycle: json['cycle'] as String? ?? 'MONTHLY',
      lateFinePerDay: (json['lateFinePerDay'] as num?)?.toDouble() ?? 0,
      isActive: json['isActive'] as bool? ?? true,
      assignmentCount: count?['assignments'] as int? ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
    );
  }

  String get cycleLabel {
    switch (cycle) {
      case 'ONCE':
        return 'One-time';
      case 'MONTHLY':
        return 'Monthly';
      case 'QUARTERLY':
        return 'Quarterly';
      case 'HALF_YEARLY':
        return 'Half-yearly';
      case 'YEARLY':
        return 'Yearly';
      default:
        return 'Custom';
    }
  }
}

/// A snapshot of a mini member for fee display.
class FeeMemberInfo {
  final String memberId;
  final String? userId;
  final String? wardId;
  final String? name;
  final String? picture;
  final String? email;
  final String? phone;
  final String? parentName;
  final String? parentPhone;

  const FeeMemberInfo({
    required this.memberId,
    this.userId,
    this.wardId,
    this.name,
    this.picture,
    this.email,
    this.phone,
    this.parentName,
    this.parentPhone,
  });

  factory FeeMemberInfo.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    final ward = json['ward'] as Map<String, dynamic>?;
    final parent = ward?['parent'] as Map<String, dynamic>?;
    return FeeMemberInfo(
      memberId: json['id'] as String,
      userId: json['userId'] as String?,
      wardId: json['wardId'] as String?,
      name: user?['name'] as String? ?? ward?['name'] as String?,
      picture: user?['picture'] as String? ?? ward?['picture'] as String?,
      email: user?['email'] as String?,
      phone: user?['phone'] as String?,
      parentName: parent?['name'] as String?,
      parentPhone: parent?['phone'] as String?,
    );
  }
}

/// A single payment entry (full or partial).
class FeePaymentModel {
  final String id;
  final double amount;
  final String mode;
  final String? transactionRef;
  final String? receiptNo;
  final String? notes;
  final DateTime paidAt;

  const FeePaymentModel({
    required this.id,
    required this.amount,
    required this.mode,
    this.transactionRef,
    this.receiptNo,
    this.notes,
    required this.paidAt,
  });

  factory FeePaymentModel.fromJson(Map<String, dynamic> json) {
    return FeePaymentModel(
      id: json['id'] as String,
      amount: (json['amount'] as num).toDouble(),
      mode: json['mode'] as String,
      transactionRef: json['transactionRef'] as String?,
      receiptNo: json['receiptNo'] as String?,
      notes: json['notes'] as String?,
      paidAt: DateTime.parse(json['paidAt'] as String),
    );
  }

  String get modeLabel {
    switch (mode) {
      case 'CASH':
        return 'Cash';
      case 'ONLINE':
        return 'Online';
      case 'UPI':
        return 'UPI';
      case 'BANK_TRANSFER':
        return 'Bank Transfer';
      case 'CHEQUE':
        return 'Cheque';
      default:
        return mode;
    }
  }
}

/// A single payable instance for a student (e.g. "April 2025 Tuition").
class FeeRecordModel {
  final String id;
  final String coachingId;
  final String memberId;
  final String assignmentId;
  final String title;
  final double baseAmount;
  final double discountAmount;
  final double fineAmount;
  final double finalAmount;
  final double paidAmount;
  final DateTime dueDate;
  final DateTime? paidAt;
  final String status; // PENDING | PAID | PARTIALLY_PAID | OVERDUE | WAIVED
  final String? paymentMode;
  final String? transactionRef;
  final String? receiptNo;
  final String? notes;
  final DateTime? reminderSentAt;
  final int reminderCount;

  // Embedded
  final FeeMemberInfo? member;
  final FeeStructureModel? feeStructure;
  final List<FeePaymentModel> payments;

  const FeeRecordModel({
    required this.id,
    required this.coachingId,
    required this.memberId,
    required this.assignmentId,
    required this.title,
    required this.baseAmount,
    this.discountAmount = 0,
    this.fineAmount = 0,
    required this.finalAmount,
    this.paidAmount = 0,
    required this.dueDate,
    this.paidAt,
    required this.status,
    this.paymentMode,
    this.transactionRef,
    this.receiptNo,
    this.notes,
    this.reminderSentAt,
    this.reminderCount = 0,
    this.member,
    this.feeStructure,
    this.payments = const [],
  });

  factory FeeRecordModel.fromJson(Map<String, dynamic> json) {
    final assignment = json['assignment'] as Map<String, dynamic>?;
    final structure = assignment?['feeStructure'] as Map<String, dynamic>?;
    final memberJson = json['member'] as Map<String, dynamic>?;
    final paymentsList = json['payments'] as List<dynamic>?;
    return FeeRecordModel(
      id: json['id'] as String,
      coachingId: json['coachingId'] as String,
      memberId: json['memberId'] as String,
      assignmentId: json['assignmentId'] as String,
      title: json['title'] as String,
      baseAmount: (json['baseAmount'] as num).toDouble(),
      discountAmount: (json['discountAmount'] as num?)?.toDouble() ?? 0,
      fineAmount: (json['fineAmount'] as num?)?.toDouble() ?? 0,
      finalAmount: (json['finalAmount'] as num).toDouble(),
      paidAmount: (json['paidAmount'] as num?)?.toDouble() ?? 0,
      dueDate: DateTime.parse(json['dueDate'] as String),
      paidAt: json['paidAt'] != null
          ? DateTime.tryParse(json['paidAt'] as String)
          : null,
      status: json['status'] as String,
      paymentMode: json['paymentMode'] as String?,
      transactionRef: json['transactionRef'] as String?,
      receiptNo: json['receiptNo'] as String?,
      notes: json['notes'] as String?,
      reminderSentAt: json['reminderSentAt'] != null
          ? DateTime.tryParse(json['reminderSentAt'] as String)
          : null,
      reminderCount: json['reminderCount'] as int? ?? 0,
      member: memberJson != null ? FeeMemberInfo.fromJson(memberJson) : null,
      feeStructure: structure != null
          ? FeeStructureModel.fromJson(structure)
          : null,
      payments:
          paymentsList
              ?.map((e) => FeePaymentModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  double get balance => finalAmount - paidAmount;
  bool get isOverdue => status == 'OVERDUE';
  bool get isPaid => status == 'PAID';
  bool get isPartial => status == 'PARTIALLY_PAID';
  bool get isWaived => status == 'WAIVED';
}

/// Summary / analytics response.
class FeeSummaryModel {
  final double totalCollected;
  final double totalPending;
  final double totalOverdue;
  final List<FeeStatusGroup> statusBreakdown;
  final List<FeePaymentModeGroup> paymentModes;
  final List<FeeMonthlyData> monthlyCollection;

  const FeeSummaryModel({
    required this.totalCollected,
    required this.totalPending,
    required this.totalOverdue,
    required this.statusBreakdown,
    required this.paymentModes,
    required this.monthlyCollection,
  });

  factory FeeSummaryModel.fromJson(Map<String, dynamic> json) {
    return FeeSummaryModel(
      totalCollected: (json['totalCollected'] as num?)?.toDouble() ?? 0,
      totalPending: (json['totalPending'] as num?)?.toDouble() ?? 0,
      totalOverdue: (json['totalOverdue'] as num?)?.toDouble() ?? 0,
      statusBreakdown:
          (json['statusBreakdown'] as List<dynamic>?)
              ?.map((e) => FeeStatusGroup.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      paymentModes:
          (json['paymentModes'] as List<dynamic>?)
              ?.map(
                (e) => FeePaymentModeGroup.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
      monthlyCollection:
          (json['monthlyCollection'] as List<dynamic>?)
              ?.map((e) => FeeMonthlyData.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class FeeStatusGroup {
  final String status;
  final int count;
  final double totalAmount;
  const FeeStatusGroup({
    required this.status,
    required this.count,
    required this.totalAmount,
  });
  factory FeeStatusGroup.fromJson(Map<String, dynamic> json) {
    final sum = json['_sum'] as Map<String, dynamic>?;
    return FeeStatusGroup(
      status: json['status'] as String,
      count: json['_count'] as int? ?? 0,
      totalAmount: (sum?['finalAmount'] as num?)?.toDouble() ?? 0,
    );
  }
}

class FeePaymentModeGroup {
  final String mode;
  final int count;
  final double total;
  const FeePaymentModeGroup({
    required this.mode,
    required this.count,
    required this.total,
  });
  factory FeePaymentModeGroup.fromJson(Map<String, dynamic> json) {
    final sum = json['_sum'] as Map<String, dynamic>?;
    return FeePaymentModeGroup(
      mode: json['mode'] as String,
      count: json['_count'] as int? ?? 0,
      total: (sum?['amount'] as num?)?.toDouble() ?? 0,
    );
  }
}

class FeeMonthlyData {
  final String month; // "2025-04"
  final double total;
  const FeeMonthlyData({required this.month, required this.total});
  factory FeeMonthlyData.fromJson(Map<String, dynamic> json) {
    return FeeMonthlyData(
      month: json['month'] as String,
      total: (json['total'] as num?)?.toDouble() ?? 0,
    );
  }
}
