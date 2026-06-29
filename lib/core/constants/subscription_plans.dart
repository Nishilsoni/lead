// Static subscription catalogue for the expiry paywall.
//
// The backend has no "list purchasable plans" endpoint, so the web app hard
// codes these tiers/prices and so do we — kept here in one place to match the
// web pricing exactly. Prices are in INR (₹), base is the monthly price; longer
// billing cycles apply the cycle discount.

enum BillingCycle { monthly, quarterly, halfYearly, yearly }

extension BillingCycleInfo on BillingCycle {
  /// Number of months billed up front.
  int get months => switch (this) {
        BillingCycle.monthly => 1,
        BillingCycle.quarterly => 3,
        BillingCycle.halfYearly => 6,
        BillingCycle.yearly => 12,
      };

  /// Fractional discount applied to the cycle total.
  double get discount => switch (this) {
        BillingCycle.monthly => 0.0,
        BillingCycle.quarterly => 0.05,
        BillingCycle.halfYearly => 0.10,
        BillingCycle.yearly => 0.25,
      };

  /// Short tab label, e.g. "Monthly".
  String get label => switch (this) {
        BillingCycle.monthly => 'Monthly',
        BillingCycle.quarterly => 'Quarterly',
        BillingCycle.halfYearly => '6 Months',
        BillingCycle.yearly => 'Yearly',
      };

  /// Discount badge text shown next to the tab, e.g. "5% off" (empty for monthly).
  String get discountLabel => switch (this) {
        BillingCycle.monthly => '',
        BillingCycle.quarterly => '5% off',
        BillingCycle.halfYearly => '10% off',
        BillingCycle.yearly => '25% off',
      };

  /// Suffix under the price, e.g. "per month", "per quarter".
  String get periodSuffix => switch (this) {
        BillingCycle.monthly => 'per month',
        BillingCycle.quarterly => 'per quarter',
        BillingCycle.halfYearly => 'per 6 months',
        BillingCycle.yearly => 'per year',
      };

  /// Value sent to the backend `billing_cycle` enum (matches the API exactly).
  String get apiValue => switch (this) {
        BillingCycle.monthly => 'monthly',
        BillingCycle.quarterly => 'quarterly',
        BillingCycle.halfYearly => 'halfYearly',
        BillingCycle.yearly => 'yearly',
      };
}

/// A single feature line on a plan card.
class PlanFeature {
  final String label;

  /// Optional small badge after the label, e.g. "Fast Moving".
  final String? badge;

  const PlanFeature(this.label, [this.badge]);
}

/// A purchasable plan tier.
class SubscriptionPlan {
  /// Stable id sent to the backend, e.g. "standard" / "professional".
  final String id;
  final String name;

  /// Base price per month in INR (before any cycle discount).
  final int monthlyPrice;
  final String usersLabel;
  final List<PlanFeature> features;
  final bool isRecommended;

  /// Optional "+N more features" line (Professional has extras).
  final String? extraNote;

  const SubscriptionPlan({
    required this.id,
    required this.name,
    required this.monthlyPrice,
    required this.usersLabel,
    required this.features,
    this.isRecommended = false,
    this.extraNote,
  });

  /// Total charge (INR) for the given billing cycle, discount applied & rounded.
  int totalFor(BillingCycle cycle) {
    final raw = monthlyPrice * cycle.months * (1 - cycle.discount);
    return raw.round();
  }

  /// Effective per-month price (INR) after the cycle discount.
  int perMonthFor(BillingCycle cycle) =>
      (totalFor(cycle) / cycle.months).round();
}

/// The plan catalogue, matching the web pricing page.
class SubscriptionCatalog {
  SubscriptionCatalog._();

  static const List<PlanFeature> _baseFeatures = [
    PlanFeature('Lead Management'),
    PlanFeature('Task Management'),
    PlanFeature('Appointment Scheduling'),
    PlanFeature('Multi-language Support'),
    PlanFeature('AWS Cloud Hosting & Security'),
    PlanFeature('Weekly Product Updates', 'Fast Moving'),
  ];

  static const SubscriptionPlan standard = SubscriptionPlan(
    id: 'standard',
    name: 'Standard',
    monthlyPrice: 999,
    usersLabel: 'Up to 5 users',
    features: _baseFeatures,
  );

  static const SubscriptionPlan professional = SubscriptionPlan(
    id: 'professional',
    name: 'Professional',
    monthlyPrice: 1999,
    usersLabel: 'Up to 5 users',
    isRecommended: true,
    extraNote: '+9 more features',
    features: _baseFeatures,
  );

  static const List<SubscriptionPlan> plans = [standard, professional];

  static const List<BillingCycle> cycles = BillingCycle.values;
}
