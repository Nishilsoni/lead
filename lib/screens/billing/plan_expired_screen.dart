import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_theme.dart';
import '../../core/constants/subscription_plans.dart';
import '../../models/plan.dart';
import '../../providers/auth_provider.dart';
import '../../providers/lead_provider.dart';
import '../../providers/tag_provider.dart';
import '../../services/billing_service.dart';
import 'razorpay_checkout_webview.dart';

/// Full-screen, non-dismissible paywall shown when the org's plan/trial has
/// expired. The user must pay to continue (or log out) — they cannot close it.
class PlanExpiredScreen extends StatefulWidget {
  /// The expired plan (drives the variable heading + org name).
  final Plan plan;

  /// Called after a payment is verified, so the gate re-checks plan status.
  final Future<void> Function() onPaid;

  const PlanExpiredScreen({
    super.key,
    required this.plan,
    required this.onPaid,
  });

  @override
  State<PlanExpiredScreen> createState() => _PlanExpiredScreenState();
}

class _PlanExpiredScreenState extends State<PlanExpiredScreen> {
  final BillingService _billing = BillingService();
  BillingCycle _cycle = BillingCycle.monthly;
  String? _processingPlanId; // plan id whose payment is in flight

  Future<void> _choosePlan(SubscriptionPlan plan) async {
    if (_processingPlanId != null) return;
    setState(() => _processingPlanId = plan.id);
    final messenger = ScaffoldMessenger.of(context);
    try {
      // 1. Create the Razorpay order on the backend.
      final order = await _billing.createOrder(
        plan: plan,
        cycle: _cycle,
        userCount: widget.plan.maxUsers,
        prefillName: widget.plan.organizationName,
      );
      if (order.orderId.isEmpty || order.keyId.isEmpty) {
        throw 'Could not start payment. Please try again.';
      }
      if (!mounted) return;

      // 2. Run Razorpay checkout in a WebView.
      final result = await Navigator.of(context).push<RazorpayResult>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => RazorpayCheckoutWebView(
            order: order,
            planName: plan.name,
            orgName: widget.plan.organizationName,
          ),
        ),
      );

      if (result == null || !result.success) {
        if (mounted && result?.error != null) {
          _showError(messenger, result!.error!);
        }
        return;
      }

      // 3. Verify the payment server-side so the plan is activated.
      final verified = await _billing.verifyPayment(
        orderId: result.orderId ?? order.orderId,
        paymentId: result.paymentId ?? '',
        signature: result.signature ?? '',
      );
      if (!verified) {
        throw 'Payment verification failed. If you were charged, contact support.';
      }

      // 4. Re-check plan status (parent gate dismisses this screen on success).
      await widget.onPaid();
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Payment successful — welcome back!',
                style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      _showError(messenger, e.toString());
    } finally {
      if (mounted) setState(() => _processingPlanId = null);
    }
  }

  void _showError(ScaffoldMessengerState messenger, String message) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Log out',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 17)),
        content: Text(
          'You can log back in any time. Your plan stays expired until payment.',
          style: GoogleFonts.inter(
              fontSize: 14, color: AppTheme.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<LeadProvider>().clearCache();
              context.read<TagProvider>().clearCache();
              context.read<AuthProvider>().logout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              elevation: 0,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Log out',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Block all back navigation — the user must pay (or log out) to leave.
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppTheme.scaffoldBg,
        body: SafeArea(
          child: Column(
            children: [
              // Top bar with logout only (no close).
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      tooltip: 'Log out',
                      onPressed: _confirmLogout,
                      icon: const Icon(Icons.power_settings_new_rounded,
                          color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                  child: Column(
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 22),
                      _buildCycleSelector(),
                      const SizedBox(height: 20),
                      ...SubscriptionCatalog.plans.map(_buildPlanCard),
                      const SizedBox(height: 8),
                      Text(
                        'Need help choosing? Contact our support team.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          color: AppTheme.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Text('⏰', style: TextStyle(fontSize: 30)),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          widget.plan.expiryTitle,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.plan.expirySubtitle,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: AppTheme.textSecondary,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildCycleSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: SubscriptionCatalog.cycles.map((cycle) {
          final selected = cycle == _cycle;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => setState(() => _cycle = cycle),
              borderRadius: BorderRadius.circular(24),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                  color: selected
                      ? AppTheme.primaryBlue.withValues(alpha: 0.1)
                      : const Color(0xFFF1F4F9),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: selected
                        ? AppTheme.primaryBlue
                        : Colors.transparent,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      cycle.label,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? AppTheme.primaryBlue
                            : AppTheme.textSecondary,
                      ),
                    ),
                    if (cycle.discountLabel.isNotEmpty) ...[
                      const SizedBox(width: 5),
                      Text(
                        '(${cycle.discountLabel})',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPlanCard(SubscriptionPlan plan) {
    final recommended = plan.isRecommended;
    final accent = AppTheme.primaryBlue;
    final total = plan.totalFor(_cycle);
    final processing = _processingPlanId == plan.id;
    final anyProcessing = _processingPlanId != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: recommended ? accent : Colors.grey.shade200,
          width: recommended ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: recommended ? 0.06 : 0.03),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          if (recommended)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: accent,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Text(
                'Recommended',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              children: [
                Text(
                  plan.name,
                  style: GoogleFonts.inter(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '₹${_formatPrice(total)}',
                  style: GoogleFonts.inter(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _cycle.periodSuffix,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    color: AppTheme.textSecondary,
                  ),
                ),
                if (_cycle != BillingCycle.monthly) ...[
                  const SizedBox(height: 2),
                  Text(
                    '≈ ₹${_formatPrice(plan.perMonthFor(_cycle))}/mo',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF10B981),
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  plan.usersLabel,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                Divider(height: 1, color: Colors.grey.shade100),
                const SizedBox(height: 14),
                ...plan.features.map(_buildFeatureRow),
                if (plan.extraNote != null) ...[
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      plan.extraNote!,
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: anyProcessing ? null : () => _choosePlan(plan),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          recommended ? accent : const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFCBD5E1),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: processing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.2, color: Colors.white),
                          )
                        : Text(
                            'Choose ${plan.name}',
                            style: GoogleFonts.inter(
                                fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(PlanFeature feature) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          const Icon(Icons.check_rounded, size: 17, color: Color(0xFF10B981)),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              feature.label,
              style: GoogleFonts.inter(
                fontSize: 13.5,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          if (feature.badge != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                feature.badge!,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF059669),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Indian-style grouping: 1999 → 1,999; 11988 → 11,988; 119880 → 1,19,880.
  String _formatPrice(int value) {
    final s = value.toString();
    if (s.length <= 3) return s;
    final last3 = s.substring(s.length - 3);
    final rest = s.substring(0, s.length - 3);
    final grouped =
        rest.replaceAllMapped(RegExp(r'(\d)(?=(\d\d)+$)'), (m) => '${m[1]},');
    return '$grouped,$last3';
  }
}
