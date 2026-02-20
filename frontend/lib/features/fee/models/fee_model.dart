/// A reusable fee template (e.g. "Monthly Tuition ₹2500").
class FeeStructureModel {
  final String id;
  final String coachingId;
  final String name;
  final String? description;
  final double amount;
  final String currency;
  final String
  cycle; // ONCE | MONTHLY | QUARTERLY | HALF_YEARLY | YEARLY | INSTALLMENT
  final double lateFinePerDay;
  final bool isActive;
  final int assignmentCount;
  final DateTime? createdAt;
  final List<InstallmentPlanItem> installmentPlan;

  // Tax configuration
  final String taxType; // NONE | GST_INCLUSIVE | GST_EXCLUSIVE
  final double gstRate; // 0 | 5 | 12 | 18 | 28
  final String? sacCode;
  final String? hsnCode;
  final String gstSupplyType; // INTRA_STATE | INTER_STATE
  final double cessRate;
  final List<LineItemModel> lineItems;

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
    this.installmentPlan = const [],
    this.taxType = 'NONE',
    this.gstRate = 0,
    this.sacCode,
    this.hsnCode,
    this.gstSupplyType = 'INTRA_STATE',
    this.cessRate = 0,
    this.lineItems = const [],
  });

  factory FeeStructureModel.fromJson(Map<String, dynamic> json) {
    final count = json['_count'] as Map<String, dynamic>?;
    final planJson = json['installmentPlan'] as List<dynamic>?;
    final itemsJson = json['lineItems'] as List<dynamic>?;
    return FeeStructureModel(
      id: json['id'] as String? ?? '',
      coachingId: json['coachingId'] as String? ?? '',
      name: json['name'] as String? ?? 'Untitled Structure',
      description: json['description'] as String?,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? 'INR',
      cycle: json['cycle'] as String? ?? 'MONTHLY',
      lateFinePerDay: (json['lateFinePerDay'] as num?)?.toDouble() ?? 0,
      isActive: json['isActive'] as bool? ?? true,
      assignmentCount: count?['assignments'] as int? ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      installmentPlan:
          planJson
              ?.map(
                (e) => InstallmentPlanItem.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
      taxType: json['taxType'] as String? ?? 'NONE',
      gstRate: (json['gstRate'] as num?)?.toDouble() ?? 0,
      sacCode: json['sacCode'] as String?,
      hsnCode: json['hsnCode'] as String?,
      gstSupplyType: json['gstSupplyType'] as String? ?? 'INTRA_STATE',
      cessRate: (json['cessRate'] as num?)?.toDouble() ?? 0,
      lineItems:
          itemsJson
              ?.map((e) => LineItemModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  bool get hasTax => taxType != 'NONE' && gstRate > 0;

  /// Serialize to JSON for API calls (create/update).
  Map<String, dynamic> toJson() => {
    'name': name,
    'amount': amount,
    'cycle': cycle,
    'lateFinePerDay': lateFinePerDay,
    if (description != null) 'description': description,
    if (taxType != 'NONE') 'taxType': taxType,
    if (gstRate > 0) 'gstRate': gstRate,
    if (sacCode != null) 'sacCode': sacCode,
    if (hsnCode != null) 'hsnCode': hsnCode,
    if (gstSupplyType != 'INTRA_STATE') 'gstSupplyType': gstSupplyType,
    if (cessRate > 0) 'cessRate': cessRate,
    if (lineItems.isNotEmpty)
      'lineItems': lineItems.map((e) => e.toJson()).toList(),
    if (installmentPlan.isNotEmpty)
      'installmentPlan': installmentPlan.map((e) => e.toJson()).toList(),
  };

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
      case 'INSTALLMENT':
        return 'Installment';
      default:
        return 'Custom';
    }
  }
}

class InstallmentPlanItem {
  final String label;
  final int dueDay;
  final double amount;
  const InstallmentPlanItem({
    required this.label,
    required this.dueDay,
    required this.amount,
  });
  factory InstallmentPlanItem.fromJson(Map<String, dynamic> json) =>
      InstallmentPlanItem(
        label: json['label'] as String? ?? '',
        dueDay: (json['dueDay'] as num?)?.toInt() ?? 1,
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
      );
  Map<String, dynamic> toJson() => {
    'label': label,
    'dueDay': dueDay,
    'amount': amount,
  };
}

/// A single line item within a fee structure (e.g. "Books", "Lab Fee").
class LineItemModel {
  final String label;
  final double amount;
  const LineItemModel({required this.label, required this.amount});
  factory LineItemModel.fromJson(Map<String, dynamic> json) => LineItemModel(
    label: json['label'] as String? ?? '',
    amount: (json['amount'] as num?)?.toDouble() ?? 0,
  );
  Map<String, dynamic> toJson() => {'label': label, 'amount': amount};
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
      memberId: json['id'] as String? ?? '',
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
  final String? razorpayPaymentId;
  final String? razorpayOrderId;

  const FeePaymentModel({
    required this.id,
    required this.amount,
    required this.mode,
    this.transactionRef,
    this.receiptNo,
    this.notes,
    required this.paidAt,
    this.razorpayPaymentId,
    this.razorpayOrderId,
  });

  factory FeePaymentModel.fromJson(Map<String, dynamic> json) {
    return FeePaymentModel(
      id: json['id'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      mode: json['mode'] as String? ?? 'CASH',
      transactionRef: json['transactionRef'] as String?,
      receiptNo: json['receiptNo'] as String?,
      notes: json['notes'] as String?,
      paidAt:
          DateTime.tryParse(json['paidAt'] as String? ?? '') ?? DateTime.now(),
      razorpayPaymentId: json['razorpayPaymentId'] as String?,
      razorpayOrderId: json['razorpayOrderId'] as String?,
    );
  }

  bool get isOnline => razorpayPaymentId != null;

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
      case 'RAZORPAY':
        return 'Razorpay';
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
  final int daysOverdue;

  // Tax snapshot
  final String taxType; // NONE | GST_INCLUSIVE | GST_EXCLUSIVE
  final double taxAmount;
  final double cgstAmount;
  final double sgstAmount;
  final double igstAmount;
  final double cessAmount;
  final double gstRate;
  final String? sacCode;
  final String? hsnCode;
  final List<LineItemModel> lineItems;

  // Embedded
  final FeeMemberInfo? member;
  final FeeStructureModel? feeStructure;
  final List<FeePaymentModel> payments;
  final List<FeeRefundModel> refunds;

  // Assignment info (validity period)
  final DateTime? assignedAt;
  final DateTime? validFrom;
  final DateTime? validUntil;

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
    this.daysOverdue = 0,
    this.taxType = 'NONE',
    this.taxAmount = 0,
    this.cgstAmount = 0,
    this.sgstAmount = 0,
    this.igstAmount = 0,
    this.cessAmount = 0,
    this.gstRate = 0,
    this.sacCode,
    this.hsnCode,
    this.lineItems = const [],
    this.member,
    this.feeStructure,
    this.payments = const [],
    this.refunds = const [],
    this.assignedAt,
    this.validFrom,
    this.validUntil,
  });

  factory FeeRecordModel.fromJson(Map<String, dynamic> json) {
    final assignment = json['assignment'] as Map<String, dynamic>?;
    final structure = assignment?['feeStructure'] as Map<String, dynamic>?;
    final memberJson = json['member'] as Map<String, dynamic>?;
    final paymentsList = json['payments'] as List<dynamic>?;
    final refundsList = json['refunds'] as List<dynamic>?;
    final itemsJson = json['lineItems'] as List<dynamic>?;
    return FeeRecordModel(
      id: json['id'] as String? ?? '',
      coachingId: json['coachingId'] as String? ?? '',
      memberId: json['memberId'] as String? ?? '',
      assignmentId: json['assignmentId'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled Fee',
      baseAmount: (json['baseAmount'] as num?)?.toDouble() ?? 0,
      discountAmount: (json['discountAmount'] as num?)?.toDouble() ?? 0,
      fineAmount: (json['fineAmount'] as num?)?.toDouble() ?? 0,
      finalAmount: (json['finalAmount'] as num?)?.toDouble() ?? 0,
      paidAmount: (json['paidAmount'] as num?)?.toDouble() ?? 0,
      dueDate: json['dueDate'] != null
          ? DateTime.tryParse(json['dueDate'] as String) ?? DateTime.now()
          : DateTime.now(),
      paidAt: json['paidAt'] != null
          ? DateTime.tryParse(json['paidAt'] as String)
          : null,
      status: json['status'] as String? ?? 'PENDING',
      paymentMode: json['paymentMode'] as String?,
      transactionRef: json['transactionRef'] as String?,
      receiptNo: json['receiptNo'] as String?,
      notes: json['notes'] as String?,
      reminderSentAt: json['reminderSentAt'] != null
          ? DateTime.tryParse(json['reminderSentAt'] as String)
          : null,
      reminderCount: json['reminderCount'] as int? ?? 0,
      daysOverdue: json['daysOverdue'] as int? ?? 0,
      taxType: json['taxType'] as String? ?? 'NONE',
      taxAmount: (json['taxAmount'] as num?)?.toDouble() ?? 0,
      cgstAmount: (json['cgstAmount'] as num?)?.toDouble() ?? 0,
      sgstAmount: (json['sgstAmount'] as num?)?.toDouble() ?? 0,
      igstAmount: (json['igstAmount'] as num?)?.toDouble() ?? 0,
      cessAmount: (json['cessAmount'] as num?)?.toDouble() ?? 0,
      gstRate: (json['gstRate'] as num?)?.toDouble() ?? 0,
      sacCode: json['sacCode'] as String?,
      hsnCode: json['hsnCode'] as String?,
      lineItems:
          itemsJson
              ?.map((e) => LineItemModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      member: memberJson != null ? FeeMemberInfo.fromJson(memberJson) : null,
      feeStructure: structure != null
          ? FeeStructureModel.fromJson(structure)
          : null,
      payments:
          paymentsList
              ?.map((e) => FeePaymentModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      refunds:
          refundsList
              ?.map((e) => FeeRefundModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      // Assignment dates
      assignedAt: assignment?['createdAt'] != null
          ? DateTime.tryParse(assignment!['createdAt'] as String)
          : null,
      validFrom: assignment?['startDate'] != null
          ? DateTime.tryParse(assignment!['startDate'] as String)
          : null,
      validUntil: assignment?['endDate'] != null
          ? DateTime.tryParse(assignment!['endDate'] as String)
          : null,
    );
  }

  double get balance => finalAmount - paidAmount;
  bool get isOverdue => status == 'OVERDUE';
  bool get isPaid => status == 'PAID';
  bool get isPartial => status == 'PARTIALLY_PAID';
  bool get isWaived => status == 'WAIVED';
  bool get hasTax => taxType != 'NONE' && taxAmount > 0;
}

/// A fee assignment linking a structure to a student.
class FeeAssignmentModel {
  final String id;
  final String coachingId;
  final String memberId;
  final String feeStructureId;
  final double? customAmount;
  final double discountAmount;
  final String? discountReason;
  final String? scholarshipTag;
  final double scholarshipAmount;
  final bool isActive;
  final bool isPaused;
  final String? pauseNote;
  final DateTime? pausedAt;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? createdAt;
  final FeeStructureModel? feeStructure;
  final List<FeeRecordModel> records;
  final FeeMemberInfo? member;

  const FeeAssignmentModel({
    required this.id,
    required this.coachingId,
    required this.memberId,
    required this.feeStructureId,
    this.customAmount,
    this.discountAmount = 0,
    this.discountReason,
    this.scholarshipTag,
    this.scholarshipAmount = 0,
    this.isActive = true,
    this.isPaused = false,
    this.pauseNote,
    this.pausedAt,
    this.startDate,
    this.endDate,
    this.createdAt,
    this.feeStructure,
    this.records = const [],
    this.member,
  });

  factory FeeAssignmentModel.fromJson(Map<String, dynamic> json) {
    final structureJson = json['feeStructure'] as Map<String, dynamic>?;
    final recordsList = json['records'] as List<dynamic>?;
    final memberJson = json['member'] as Map<String, dynamic>?;
    return FeeAssignmentModel(
      id: json['id'] as String? ?? '',
      coachingId: json['coachingId'] as String? ?? '',
      memberId: json['memberId'] as String? ?? '',
      feeStructureId: json['feeStructureId'] as String? ?? '',
      customAmount: (json['customAmount'] as num?)?.toDouble(),
      discountAmount: (json['discountAmount'] as num?)?.toDouble() ?? 0,
      discountReason: json['discountReason'] as String?,
      scholarshipTag: json['scholarshipTag'] as String?,
      scholarshipAmount: (json['scholarshipAmount'] as num?)?.toDouble() ?? 0,
      isActive: json['isActive'] as bool? ?? true,
      isPaused: json['isPaused'] as bool? ?? false,
      pauseNote: json['pauseNote'] as String?,
      pausedAt: json['pausedAt'] != null
          ? DateTime.tryParse(json['pausedAt'] as String)
          : null,
      startDate: json['startDate'] != null
          ? DateTime.tryParse(json['startDate'] as String)
          : null,
      endDate: json['endDate'] != null
          ? DateTime.tryParse(json['endDate'] as String)
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      feeStructure: structureJson != null
          ? FeeStructureModel.fromJson(structureJson)
          : null,
      records:
          recordsList
              ?.map((e) => FeeRecordModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      member: memberJson != null ? FeeMemberInfo.fromJson(memberJson) : null,
    );
  }

  /// Effective amount per cycle (custom or structure amount minus discounts).
  double get effectiveAmount =>
      (customAmount ?? feeStructure?.amount ?? 0) -
      discountAmount -
      scholarshipAmount;
}

/// A single refund entry.
class FeeRefundModel {
  final String id;
  final double amount;
  final String? reason;
  final String mode;
  final DateTime refundedAt;

  const FeeRefundModel({
    required this.id,
    required this.amount,
    this.reason,
    this.mode = 'CASH',
    required this.refundedAt,
  });

  factory FeeRefundModel.fromJson(Map<String, dynamic> json) => FeeRefundModel(
    id: json['id'] as String? ?? '',
    amount: (json['amount'] as num?)?.toDouble() ?? 0,
    reason: json['reason'] as String?,
    mode: json['mode'] as String? ?? 'CASH',
    refundedAt:
        DateTime.tryParse(json['refundedAt'] as String? ?? '') ??
        DateTime.now(),
  );
}

/// Summary / analytics response.
class FeeSummaryModel {
  final double totalCollected;
  final double totalRefunded;
  final double totalPending;
  final double totalOverdue;
  final int overdueCount;
  final double todayCollection;
  final String? financialYear;
  final List<FeeStatusGroup> statusBreakdown;
  final List<FeePaymentModeGroup> paymentModes;
  final List<FeeMonthlyData> monthlyCollection;

  const FeeSummaryModel({
    required this.totalCollected,
    this.totalRefunded = 0,
    required this.totalPending,
    required this.totalOverdue,
    this.overdueCount = 0,
    this.todayCollection = 0,
    this.financialYear,
    required this.statusBreakdown,
    required this.paymentModes,
    required this.monthlyCollection,
  });

  factory FeeSummaryModel.fromJson(Map<String, dynamic> json) {
    return FeeSummaryModel(
      totalCollected: (json['totalCollected'] as num?)?.toDouble() ?? 0,
      totalRefunded: (json['totalRefunded'] as num?)?.toDouble() ?? 0,
      totalPending: (json['totalPending'] as num?)?.toDouble() ?? 0,
      totalOverdue: (json['totalOverdue'] as num?)?.toDouble() ?? 0,
      overdueCount: json['overdueCount'] as int? ?? 0,
      todayCollection: (json['todayCollection'] as num?)?.toDouble() ?? 0,
      financialYear: json['financialYear'] as String?,
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
      status: json['status'] as String? ?? 'UNKNOWN',
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
      mode: json['mode'] as String? ?? 'CASH',
      count: json['_count'] as int? ?? 0,
      total: (sum?['amount'] as num?)?.toDouble() ?? 0,
    );
  }
}

class FeeMonthlyData {
  final String month; // "2025-04"
  final double total;
  final int count;
  const FeeMonthlyData({
    required this.month,
    required this.total,
    this.count = 0,
  });
  factory FeeMonthlyData.fromJson(Map<String, dynamic> json) {
    return FeeMonthlyData(
      month: json['month'] as String? ?? '',
      total: (json['total'] as num?)?.toDouble() ?? 0,
      count: json['count'] as int? ?? 0,
    );
  }
}

/// A single entry in a student's financial ledger timeline.
class LedgerEntryModel {
  final DateTime date;
  final String type; // RECORD | PAYMENT | REFUND
  final String label;
  final double amount;
  final String? mode;
  final String? ref;
  final String? receiptNo;
  final String? status;
  final String recordId;
  final double runningBalance;

  const LedgerEntryModel({
    required this.date,
    required this.type,
    required this.label,
    required this.amount,
    this.mode,
    this.ref,
    this.receiptNo,
    this.status,
    required this.recordId,
    required this.runningBalance,
  });

  factory LedgerEntryModel.fromJson(Map<String, dynamic> json) =>
      LedgerEntryModel(
        date:
            DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
        type: json['type'] as String? ?? 'UNKNOWN',
        label: json['label'] as String? ?? '',
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        mode: json['mode'] as String?,
        ref: json['ref'] as String?,
        receiptNo: json['receiptNo'] as String?,
        status: json['status'] as String?,
        recordId: json['recordId'] as String? ?? '',
        runningBalance: (json['runningBalance'] as num?)?.toDouble() ?? 0,
      );
}

/// Student ledger summary totals.
class StudentLedgerSummary {
  final double totalCharged;
  final double totalPaid;
  final double totalRefunded;
  final double balance;
  final double totalOverdue;
  final DateTime? nextDueDate;
  final double nextDueAmount;

  const StudentLedgerSummary({
    required this.totalCharged,
    required this.totalPaid,
    required this.totalRefunded,
    required this.balance,
    required this.totalOverdue,
    this.nextDueDate,
    required this.nextDueAmount,
  });

  factory StudentLedgerSummary.fromJson(Map<String, dynamic> json) =>
      StudentLedgerSummary(
        totalCharged: (json['totalCharged'] as num?)?.toDouble() ?? 0,
        totalPaid: (json['totalPaid'] as num?)?.toDouble() ?? 0,
        totalRefunded: (json['totalRefunded'] as num?)?.toDouble() ?? 0,
        balance: (json['balance'] as num?)?.toDouble() ?? 0,
        totalOverdue: (json['totalOverdue'] as num?)?.toDouble() ?? 0,
        nextDueDate: json['nextDueDate'] != null
            ? DateTime.tryParse(json['nextDueDate'] as String)
            : null,
        nextDueAmount: (json['nextDueAmount'] as num?)?.toDouble() ?? 0,
      );
}
