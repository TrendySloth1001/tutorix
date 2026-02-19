import 'dart:async';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../../core/constants/api_constants.dart';
import '../../../shared/services/api_client.dart';

/// Handles Razorpay payment flow: order creation, checkout, verification.
class PaymentService {
  final ApiClient _api = ApiClient.instance;
  Razorpay? _razorpay;

  // ── API Calls ───────────────────────────────────────────────────

  /// Create a Razorpay order for a pending fee record.
  Future<Map<String, dynamic>> createOrder(
    String coachingId,
    String recordId, {
    double? amount,
  }) async {
    final body = <String, dynamic>{
      'recordId': recordId,
      if (amount != null) 'amount': amount,
    };
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
    return data as Map<String, dynamic>;
  }

  // ── Multi-Pay (select & pay multiple records) ────────────────────

  /// Create a combined Razorpay order for multiple fee records.
  Future<Map<String, dynamic>> createMultiOrder(
    String coachingId, {
    required List<String> recordIds,
    double? amount,
  }) async {
    final body = <String, dynamic>{
      'recordIds': recordIds,
      if (amount != null) 'amount': amount,
    };
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

  // ── Razorpay Checkout Flow ──────────────────────────────────────

  /// Opens Razorpay checkout. Returns the payment response on success.
  /// Throws on failure or user cancellation.
  Future<PaymentSuccessResponse> openCheckout({
    required String orderId,
    required int amountPaise,
    required String key,
    required String feeTitle,
    String? userEmail,
    String? userPhone,
    String? userName,
  }) async {
    _razorpay?.clear();
    _razorpay = Razorpay();

    final completer = Completer<PaymentSuccessResponse>();

    _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, (
      PaymentSuccessResponse response,
    ) {
      if (!completer.isCompleted) completer.complete(response);
    });

    _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, (
      PaymentFailureResponse response,
    ) {
      if (!completer.isCompleted) {
        completer.completeError(
          Exception(response.message ?? 'Payment failed'),
        );
      }
    });

    _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, (
      ExternalWalletResponse response,
    ) {
      if (!completer.isCompleted) {
        completer.completeError(Exception('External wallet not supported'));
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
    };

    _razorpay!.open(options);

    return completer.future;
  }

  void dispose() {
    _razorpay?.clear();
    _razorpay = null;
  }
}
