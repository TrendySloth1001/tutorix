import '../../../core/constants/api_constants.dart';
import '../../../shared/services/api_client.dart';
import '../models/plan_model.dart';
import '../models/subscription_model.dart';
import '../models/usage_model.dart';
import '../models/invoice_model.dart';

class SubscriptionService {
  SubscriptionService._();
  static final SubscriptionService instance = SubscriptionService._();

  final ApiClient _api = ApiClient.instance;

  // ── Plans (public, no auth) ──────────────────────────────────────

  Future<List<PlanModel>> getPlans() async {
    final data = await _api.getPublic(ApiConstants.subscriptionPlans);
    final list = data['plans'] as List<dynamic>? ?? [];
    return list
        .map((e) => PlanModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Subscription ─────────────────────────────────────────────────

  /// Fetches current subscription + usage for a coaching.
  Future<({SubscriptionModel subscription, UsageModel usage})> getSubscription(
    String coachingId,
  ) async {
    final data = await _api.getAuthenticated(
      ApiConstants.coachingSubscription(coachingId),
    );
    return (
      subscription: SubscriptionModel.fromJson(
        data['subscription'] as Map<String, dynamic>,
      ),
      usage: UsageModel.fromJson(data['usage'] as Map<String, dynamic>),
    );
  }

  /// Fetches only usage stats for a coaching.
  Future<UsageModel> getUsage(String coachingId) async {
    final data = await _api.getAuthenticated(
      ApiConstants.subscriptionUsage(coachingId),
    );
    return UsageModel.fromJson(data['usage'] as Map<String, dynamic>);
  }

  // ── Subscribe / Cancel ───────────────────────────────────────────

  /// Starts a paid subscription. Returns the Razorpay checkout URL.
  Future<SubscribeResult> subscribe({
    required String coachingId,
    required String planSlug,
    required String cycle, // MONTHLY or YEARLY
  }) async {
    final data = await _api.postAuthenticated(
      ApiConstants.subscriptionSubscribe(coachingId),
      body: {'planSlug': planSlug, 'cycle': cycle},
    );
    return SubscribeResult.fromJson(data);
  }

  /// Cancel the subscription at end of current billing period.
  Future<String> cancel(String coachingId) async {
    final data = await _api.postAuthenticated(
      ApiConstants.subscriptionCancel(coachingId),
    );
    return data['message'] as String? ?? 'Subscription cancelled.';
  }

  /// Verify payment after user returns from the Razorpay browser.
  /// Returns `{status, activated}`. Activates the subscription if paid.
  Future<({String status, bool activated})> verifyPayment(
    String coachingId,
  ) async {
    final data = await _api.postAuthenticated(
      ApiConstants.subscriptionVerifyPayment(coachingId),
    );
    return (
      status: data['status'] as String? ?? 'unknown',
      activated: data['activated'] as bool? ?? false,
    );
  }

  // ── Invoices ─────────────────────────────────────────────────────

  Future<List<InvoiceModel>> getInvoices(String coachingId) async {
    final data = await _api.getAuthenticated(
      ApiConstants.subscriptionInvoices(coachingId),
    );
    final list = data['invoices'] as List<dynamic>? ?? [];
    return list
        .map((e) => InvoiceModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

/// Result from subscribing — contains Razorpay subscription details.
class SubscribeResult {
  final String subscriptionId;
  final String shortUrl;
  final String planName;
  final double amount;
  final String cycle;

  const SubscribeResult({
    required this.subscriptionId,
    required this.shortUrl,
    required this.planName,
    required this.amount,
    required this.cycle,
  });

  factory SubscribeResult.fromJson(Map<String, dynamic> json) {
    return SubscribeResult(
      subscriptionId: json['subscriptionId'] as String? ?? '',
      shortUrl: json['shortUrl'] as String? ?? '',
      planName: json['planName'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      cycle: json['cycle'] as String? ?? 'MONTHLY',
    );
  }
}
