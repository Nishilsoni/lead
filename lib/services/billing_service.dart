import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/constants/api_constants.dart';
import '../core/constants/subscription_plans.dart';
import '../core/network/api_client.dart';

/// Result of creating a Razorpay order — everything the checkout needs.
class RazorpayOrder {
  /// Razorpay order id, e.g. "order_ABC123".
  final String orderId;

  /// Amount in the smallest currency unit (paise for INR).
  final int amount;
  final String currency;

  /// Razorpay public key (rzp_test_… / rzp_live_…), used to open checkout.
  final String keyId;

  const RazorpayOrder({
    required this.orderId,
    required this.amount,
    required this.currency,
    required this.keyId,
  });

  factory RazorpayOrder.fromJson(Map<String, dynamic> json) {
    // Backends differ in casing/wrapping; read the common variants.
    final data =
        json['data'] is Map<String, dynamic> ? json['data'] as Map<String, dynamic> : json;
    return RazorpayOrder(
      orderId: (data['order_id'] ?? data['id'] ?? data['razorpay_order_id'] ?? '')
          .toString(),
      amount: _toInt(data['amount']),
      currency: (data['currency'] ?? 'INR').toString(),
      keyId: (data['key_id'] ??
              data['key'] ??
              data['razorpay_key'] ??
              data['razorpay_key_id'] ??
              '')
          .toString(),
    );
  }
}

/// Service for subscription billing via Razorpay.
///
/// NOTE: the exact request/response field names for these routes aren't in the
/// published OpenAPI spec, so this uses the standard Razorpay contract and reads
/// several common field aliases defensively. If the backend differs, only this
/// file needs adjusting.
class BillingService {
  final ApiClient _client = ApiClient();

  /// Create a Razorpay order for [plan] on the chosen [cycle].
  ///
  /// Matches CreateRazorpayOrderRequest: `plan_type`, `billing_cycle`,
  /// `user_count` are required; `prefill` is optional. The backend computes the
  /// authoritative price and returns the Razorpay order to open.
  Future<RazorpayOrder> createOrder({
    required SubscriptionPlan plan,
    required BillingCycle cycle,
    required int userCount,
    String? prefillName,
    String? prefillEmail,
    String? prefillContact,
  }) async {
    final prefill = <String, dynamic>{
      if (prefillName != null && prefillName.isNotEmpty) 'name': prefillName,
      if (prefillEmail != null && prefillEmail.isNotEmpty) 'email': prefillEmail,
      if (prefillContact != null && prefillContact.isNotEmpty)
        'contact': prefillContact,
    };
    try {
      final response = await _client.dio.post(
        ApiConstants.razorpayOrder,
        data: {
          'plan_type': plan.id, // 'standard' | 'professional'
          'billing_cycle': cycle.apiValue,
          'user_count': userCount.clamp(1, 500),
          if (prefill.isNotEmpty) 'prefill': prefill,
        },
      );
      final data = response.data;
      if (data is Map<String, dynamic>) return RazorpayOrder.fromJson(data);
      throw 'Unexpected order response from server.';
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Verify a completed Razorpay payment so the backend activates the plan.
  Future<bool> verifyPayment({
    required String orderId,
    required String paymentId,
    required String signature,
  }) async {
    try {
      final response = await _client.dio.post(
        ApiConstants.razorpayVerify,
        data: {
          'razorpay_order_id': orderId,
          'razorpay_payment_id': paymentId,
          'razorpay_signature': signature,
        },
      );
      // VerifyRazorpayPaymentResponse: { status, message, invoice_* }.
      // Any 2xx whose status isn't an explicit failure means the plan is active.
      final data = response.data;
      if (data is Map) {
        final status = (data['status'] ?? data['success'] ?? '')
            .toString()
            .toLowerCase();
        if (status.isNotEmpty) {
          return !(status.contains('fail') ||
              status.contains('error') ||
              status == 'false');
        }
      }
      return true;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  String _handleError(DioException e) {
    if (kDebugMode) {
      debugPrint('[BillingService] error: ${e.response?.statusCode} ${e.response?.data}');
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Connection timed out. Please check your internet.';
    }
    if (e.type == DioExceptionType.connectionError) {
      return 'No internet connection.';
    }
    final data = e.response?.data;
    if (data is Map) {
      final detail = data['detail'] ?? data['message'] ?? data['error'];
      if (detail is String) return detail;
      if (detail is List && detail.isNotEmpty) {
        final first = detail.first;
        if (first is Map && first['msg'] != null) return first['msg'].toString();
      }
    }
    return 'Payment could not be processed. Please try again.';
  }
}

int _toInt(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? 0;
}
