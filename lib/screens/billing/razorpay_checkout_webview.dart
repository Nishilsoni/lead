import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/constants/app_theme.dart';
import '../../services/billing_service.dart';

/// Outcome of the Razorpay checkout WebView.
class RazorpayResult {
  final bool success;
  final String? paymentId;
  final String? orderId;
  final String? signature;
  final String? error;

  const RazorpayResult({
    required this.success,
    this.paymentId,
    this.orderId,
    this.signature,
    this.error,
  });
}

/// Hosts Razorpay's standard `checkout.js` inside a WebView. We build a tiny
/// local HTML page that opens checkout for the given [order], and a JS bridge
/// (`RZP`) posts the result back to Dart — success carries the payment id +
/// signature for server-side verification; dismiss/failure carry an error.
class RazorpayCheckoutWebView extends StatefulWidget {
  final RazorpayOrder order;
  final String planName;
  final String orgName;
  final String? prefillEmail;
  final String? prefillContact;

  const RazorpayCheckoutWebView({
    super.key,
    required this.order,
    required this.planName,
    required this.orgName,
    this.prefillEmail,
    this.prefillContact,
  });

  @override
  State<RazorpayCheckoutWebView> createState() =>
      _RazorpayCheckoutWebViewState();
}

class _RazorpayCheckoutWebViewState extends State<RazorpayCheckoutWebView> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..addJavaScriptChannel('RZP', onMessageReceived: _onMessage)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
        ),
      )
      ..loadHtmlString(_checkoutHtml(), baseUrl: 'https://checkout.razorpay.com');
  }

  void _onMessage(JavaScriptMessage message) {
    if (_done) return;
    try {
      final data = jsonDecode(message.message) as Map<String, dynamic>;
      final event = data['event'];
      if (event == 'success') {
        _finish(RazorpayResult(
          success: true,
          paymentId: data['razorpay_payment_id']?.toString(),
          orderId: data['razorpay_order_id']?.toString(),
          signature: data['razorpay_signature']?.toString(),
        ));
      } else if (event == 'dismiss') {
        _finish(const RazorpayResult(
            success: false, error: 'Payment cancelled.'));
      } else if (event == 'failed') {
        _finish(RazorpayResult(
          success: false,
          error: data['description']?.toString() ?? 'Payment failed.',
        ));
      }
    } catch (_) {
      // ignore malformed messages
    }
  }

  void _finish(RazorpayResult result) {
    if (_done) return;
    _done = true;
    if (mounted) Navigator.of(context).pop(result);
  }

  String _checkoutHtml() {
    final o = widget.order;
    // Encode all dynamic values as JSON so quotes/specials can't break the JS.
    String j(Object? v) => jsonEncode(v ?? '');
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <script src="https://checkout.razorpay.com/v1/checkout.js"></script>
  <style>
    html,body{height:100%;margin:0;background:#F5F7FA;font-family:-apple-system,system-ui,sans-serif;}
    .wrap{height:100%;display:flex;align-items:center;justify-content:center;}
    .msg{color:#6B7280;font-size:15px;}
  </style>
</head>
<body>
  <div class="wrap"><div class="msg">Opening secure payment…</div></div>
  <script>
    function post(payload){
      try { RZP.postMessage(JSON.stringify(payload)); } catch(e){}
    }
    var options = {
      "key": ${j(o.keyId)},
      "order_id": ${j(o.orderId)},
      "amount": ${o.amount},
      "currency": ${j(o.currency)},
      "name": ${j(widget.orgName.isNotEmpty ? widget.orgName : 'OceanCRM')},
      "description": ${j('${widget.planName} plan')},
      "prefill": {
        "email": ${j(widget.prefillEmail)},
        "contact": ${j(widget.prefillContact)}
      },
      "theme": { "color": "#1A73E8" },
      "modal": {
        "ondismiss": function(){ post({event:"dismiss"}); },
        "escape": false,
        "backdropclose": false
      },
      "handler": function(response){
        post({
          event:"success",
          razorpay_payment_id: response.razorpay_payment_id,
          razorpay_order_id: response.razorpay_order_id,
          razorpay_signature: response.razorpay_signature
        });
      }
    };
    try {
      var rzp = new Razorpay(options);
      rzp.on('payment.failed', function(resp){
        post({event:"failed", description: (resp && resp.error && resp.error.description) || "Payment failed."});
      });
      rzp.open();
    } catch(e){
      post({event:"failed", description: "Could not start checkout."});
    }
  </script>
</body>
</html>
''';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _finish(const RazorpayResult(
              success: false, error: 'Payment cancelled.'));
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.scaffoldBg,
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded, color: AppTheme.textPrimary),
            onPressed: () => _finish(const RazorpayResult(
                success: false, error: 'Payment cancelled.')),
          ),
          title: Text(
            'Secure Payment',
            style: GoogleFonts.inter(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: const Color(0xFFF1F5F9)),
          ),
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_loading)
              const LinearProgressIndicator(
                minHeight: 2.5,
                backgroundColor: Color(0xFFE5E7EB),
                color: AppTheme.primaryBlue,
              ),
          ],
        ),
      ),
    );
  }
}
