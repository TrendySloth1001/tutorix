import 'dart:async';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../../core/constants/api_constants.dart';
import '../../../shared/services/api_client.dart';

/// Handles Razorpay payment flow: order creation, checkout, verification.
class PaymentService {
  final ApiClient _api = ApiClient.instance;

  /// Single reusable Razorpay instance to avoid memory leaks from
  /// repeatedly creating/destroying native SDK instances.
  Razorpay? _razorpay;
  Completer<PaymentSuccessResponse>? _activeCompleter;

  /// Checkout timeout — prevents dangling Completers if user leaves app.
  static const _checkoutTimeout = Duration(minutes: 10);

  // ── API Calls ───────────────────────────────────────────────────

  /// Create a Razorpay order for a pending fee record.
  Future<Map<String, dynamic>> createOrder(
    String coachingId,
    String recordId,
  ) async {
    final body = <String, dynamic>{'recordId': recordId};
    final data = await _api.postAuthenticated(
      ApiConstants.feeCreateOrder(coachingId, recordId),
      body: body,
    );
    return data;
  }

  /// Verify payment after Razorpay checkout succeeds.
  Future<Map<String, dynamic>> verifyPayment(
    String coachingId,
    String recordId, {
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    final body = {
      'razorpay_order_id': razorpayOrderId,
      'razorpay_payment_id': razorpayPaymentId,
      'razorpay_signature': razorpaySignature,
    };
    final data = await _api.postAuthenticated(
      ApiConstants.feeVerifyPayment(coachingId, recordId),
      body: body,
    );
    return data;
  }

  /// Get online-only payments for a record (admin: for refund selection).
  Future<List<Map<String, dynamic>>> getOnlinePayments(
    String coachingId,
    String recordId,
  ) async {
    final data = await _api.getAuthenticatedRaw(
      ApiConstants.feeOnlinePayments(coachingId, recordId),
    );
    return (data as List<dynamic>)
        .map((e) => e as Map<String, dynamic>)
        .toList();
  }

  /// Initiate online refund (admin).
  Future<Map<String, dynamic>> initiateOnlineRefund(
    String coachingId,
    String recordId, {
    required String paymentId,
    double? amount,
    String? reason,
  }) async {
    final body = <String, dynamic>{
      'paymentId': paymentId,
      if (amount != null) 'amount': amount,
      if (reason != null) 'reason': reason,
    };
    final data = await _api.postAuthenticated(
      ApiConstants.feeOnlineRefund(coachingId, recordId),
      body: body,
    );
    return data;
  }

  /// Get Razorpay config (key + enabled).
  Future<Map<String, dynamic>> getPaymentConfig() async {
    final data = await _api.getAuthenticatedRaw(ApiConstants.paymentConfig);
    return data as Map<String, dynamic>;
  }

  /// Get coaching payment settings (bank details, GST, Razorpay linked account).
  Future<Map<String, dynamic>> getPaymentSettings(String coachingId) async {
    final data = await _api.getAuthenticatedRaw(
      ApiConstants.paymentSettings(coachingId),
    );
    return data as Map<String, dynamic>;
  }

  /// Update coaching payment settings.
  Future<Map<String, dynamic>> updatePaymentSettings(
    String coachingId, {
    String? gstNumber,
    String? panNumber,
    String? bankAccountName,
    String? bankAccountNumber,
    String? bankIfscCode,
    String? bankName,
  }) async {
    final body = <String, dynamic>{
      'gstNumber': ?gstNumber,
      'panNumber': ?panNumber,
      'bankAccountName': ?bankAccountName,
      'bankAccountNumber': ?bankAccountNumber,
      'bankIfscCode': ?bankIfscCode,
      'bankName': ?bankName,
    };
    final data = await _api.patchAuthenticated(
      ApiConstants.paymentSettings(coachingId),
      body: body,
    );
    return data;
  }

  // ── Multi-Pay (select & pay multiple records) ────────────────────

  /// Create a combined Razorpay order for multiple fee records.
  Future<Map<String, dynamic>> createMultiOrder(
    String coachingId, {
    required List<String> recordIds,
  }) async {
    final body = <String, dynamic>{'recordIds': recordIds};
    return _api.postAuthenticated(
      ApiConstants.feeMultiPayCreateOrder(coachingId),
      body: body,
    );
  }

  /// Verify multi-pay after Razorpay checkout.
  Future<Map<String, dynamic>> verifyMultiPayment(
    String coachingId, {
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    final body = {
      'razorpay_order_id': razorpayOrderId,
      'razorpay_payment_id': razorpayPaymentId,
      'razorpay_signature': razorpaySignature,
    };
    return _api.postAuthenticated(
      ApiConstants.feeMultiPayVerify(coachingId),
      body: body,
    );
  }

  // ── Failed Order Tracking ────────────────────────────────────

  /// Mark a CREATED order as FAILED (user cancelled or SDK error).
  Future<void> markOrderFailed(
    String coachingId,
    String internalOrderId,
    String reason,
  ) async {
    try {
      await _api.postAuthenticated(
        ApiConstants.feeOrderFail(coachingId, internalOrderId),
        body: {'reason': reason},
      );
    } catch (_) {
      // Best-effort — don't let fail-tracking crash the UI
    }
  }

  /// Get all FAILED orders for a specific fee record.
  Future<List<Map<String, dynamic>>> getFailedOrders(
    String coachingId,
    String recordId,
  ) async {
    try {
      final res = await _api.getAuthenticatedRaw(
        ApiConstants.feeFailedOrders(coachingId, recordId),
      );
      return (res as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  /// Get all transactions (successful + failed) for the current user in a coaching.
  /// Backend now returns paginated response: { transactions, total, page, limit }.
  Future<Map<String, dynamic>> getMyTransactions(
    String coachingId, {
    int page = 1,
    int limit = 20,
  }) async {
    final uri = Uri.parse(
      ApiConstants.feeMyTransactions(coachingId),
    ).replace(queryParameters: {'page': '$page', 'limit': '$limit'});
    final data = await _api.getAuthenticatedRaw(uri.toString());
    return data as Map<String, dynamic>;
  }

  // ── Razorpay Checkout Flow ──────────────────────────────────────

  /// Opens Razorpay checkout. Returns the payment response on success.
  /// Throws on failure or user cancellation.
  /// Includes a timeout to prevent dangling Completers.
  Future<PaymentSuccessResponse> openCheckout({
    required String orderId,
    required int amountPaise,
    required String key,
    required String feeTitle,
    String? userEmail,
    String? userPhone,
    String? userName,
  }) async {
    // Cancel any previous active checkout
    if (_activeCompleter != null && !_activeCompleter!.isCompleted) {
      _activeCompleter!.completeError(Exception('New checkout started'));
    }

    // Reuse or create Razorpay instance
    _razorpay ??= Razorpay();

    final completer = Completer<PaymentSuccessResponse>();
    _activeCompleter = completer;

    _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, (
      PaymentSuccessResponse response,
    ) {
      if (!completer.isCompleted) completer.complete(response);
    });

    _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, (
      PaymentFailureResponse response,
    ) {
      if (!completer.isCompleted) {
        final raw = response.message;
        final isBlank =
            raw == null || raw.isEmpty || raw == 'null' || raw == 'undefined';
        final msg = isBlank
            ? (response.code == 0 ? 'Payment cancelled' : 'Payment failed')
            : raw;
        completer.completeError(Exception(msg));
      }
    });

    // Handle external wallet selection (e.g., PayTM, PhonePe) gracefully
    _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, (
      ExternalWalletResponse response,
    ) {
      // External wallets redirect and verify via webhook, not client-side.
      // Complete with error so the UI shows "verifying" state and the webhook
      // will process the payment when it arrives.
      if (!completer.isCompleted) {
        completer.completeError(
          Exception(
            'Payment is being processed via ${response.walletName ?? 'external wallet'}. You will be notified once confirmed.',
          ),
        );
      }
    });

    final options = {
      'key': key,
      'amount': amountPaise,
      'currency': 'INR',
      'name': 'Tutorix',
      'description': feeTitle,
      'order_id': orderId,
      'prefill': {
        if (userEmail != null) 'email': userEmail,
        if (userPhone != null) 'contact': userPhone,
        if (userName != null) 'name': userName,
      },
      'theme': {'color': '#3D4F2F'},
      // Enable external wallets for broader payment support
      'external': {
        'wallets': ['paytm'],
      },
    };

    _razorpay!.open(options);

    // Add timeout to prevent dangling Completers
    return completer.future.timeout(
      _checkoutTimeout,
      onTimeout: () => throw TimeoutException(
        'Payment checkout timed out',
        _checkoutTimeout,
      ),
    );
  }

  void dispose() {
    if (_activeCompleter != null && !_activeCompleter!.isCompleted) {
      _activeCompleter!.completeError(Exception('Service disposed'));
    }
    _activeCompleter = null;
    _razorpay?.clear();
    _razorpay = null;
  }
}
