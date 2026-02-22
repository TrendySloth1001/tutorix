import 'plan_model.dart';

/// Active subscription for a coaching entity.
class SubscriptionModel {
  final String id;
  final String coachingId;
  final String planId;
  final PlanModel? plan;

  final String billingCycle; // MONTHLY, YEARLY
  final String status; // ACTIVE, TRIALING, PAST_DUE, CANCELLED, PAUSED, EXPIRED

  final DateTime currentPeriodStart;
  final DateTime currentPeriodEnd;
  final DateTime? trialEndsAt;
  final DateTime? cancelledAt;
  final DateTime? gracePeriodEndsAt;

  final String? razorpaySubscriptionId;

  final String? scheduledPlanId;
  final String? scheduledCycle;

  final DateTime? lastPaymentAt;
  final double? lastPaymentAmount;
  final int failedPaymentCount;

  final DateTime createdAt;

  const SubscriptionModel({
    required this.id,
    required this.coachingId,
    required this.planId,
    this.plan,
    required this.billingCycle,
    required this.status,
    required this.currentPeriodStart,
    required this.currentPeriodEnd,
    this.trialEndsAt,
    this.cancelledAt,
    this.gracePeriodEndsAt,
    this.razorpaySubscriptionId,
    this.scheduledPlanId,
    this.scheduledCycle,
    this.lastPaymentAt,
    this.lastPaymentAmount,
    this.failedPaymentCount = 0,
    required this.createdAt,
  });

  bool get isActive => status == 'ACTIVE' || status == 'TRIALING';
  bool get isPastDue => status == 'PAST_DUE';
  bool get isCancelled => status == 'CANCELLED';
  bool get isExpired => status == 'EXPIRED';
  bool get isFree => plan?.isFree ?? true;
  bool get hasPendingDowngrade => scheduledPlanId != null;

  /// Days remaining in current billing period.
  int get daysRemaining {
    final now = DateTime.now();
    if (currentPeriodEnd.isBefore(now)) return 0;
    return currentPeriodEnd.difference(now).inDays;
  }

  /// Days remaining in grace period (payment retry window).
  int get graceDaysRemaining {
    if (gracePeriodEndsAt == null) return 0;
    final now = DateTime.now();
    if (gracePeriodEndsAt!.isBefore(now)) return 0;
    return gracePeriodEndsAt!.difference(now).inDays;
  }

  factory SubscriptionModel.fromJson(Map<String, dynamic> json) {
    final planJson = json['plan'] as Map<String, dynamic>?;

    return SubscriptionModel(
      id: json['id'] as String,
      coachingId: json['coachingId'] as String,
      planId: json['planId'] as String,
      plan: planJson != null ? PlanModel.fromJson(planJson) : null,
      billingCycle: json['billingCycle'] as String? ?? 'MONTHLY',
      status: json['status'] as String? ?? 'ACTIVE',
      currentPeriodStart: DateTime.parse(json['currentPeriodStart'] as String),
      currentPeriodEnd: DateTime.parse(json['currentPeriodEnd'] as String),
      trialEndsAt: json['trialEndsAt'] != null
          ? DateTime.parse(json['trialEndsAt'] as String)
          : null,
      cancelledAt: json['cancelledAt'] != null
          ? DateTime.parse(json['cancelledAt'] as String)
          : null,
      gracePeriodEndsAt: json['gracePeriodEndsAt'] != null
          ? DateTime.parse(json['gracePeriodEndsAt'] as String)
          : null,
      razorpaySubscriptionId: json['razorpaySubscriptionId'] as String?,
      scheduledPlanId: json['scheduledPlanId'] as String?,
      scheduledCycle: json['scheduledCycle'] as String?,
      lastPaymentAt: json['lastPaymentAt'] != null
          ? DateTime.parse(json['lastPaymentAt'] as String)
          : null,
      lastPaymentAmount: (json['lastPaymentAmount'] as num?)?.toDouble(),
      failedPaymentCount: (json['failedPaymentCount'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
