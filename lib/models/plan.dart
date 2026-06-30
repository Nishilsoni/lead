class Plan {
  final String organizationId;
  final String organizationName;
  final DateTime? startedAt;
  final DateTime expiredAt;

  /// Whether `expired_at` was present and parseable. Used to FAIL OPEN: if the
  /// API gives no/invalid expiry we must NOT lock the user out of the CRM.
  final bool hasExpiry;

  /// Whether the current plan is the free trial (vs a paid subscription).
  final bool isTrial;

  /// Display name of the current plan/tier if the API exposes one
  /// (e.g. "Professional"). Empty when unknown.
  final String planName;

  /// Seats included in the plan — sent as `user_count` when creating an order.
  final int maxUsers;

  // Feature flags from plan
  final bool shopifyEnabled;
  final bool facebookEnabled;
  final bool indiamartEnabled;
  final bool whatsappEnabled;
  final bool billingEnabled;
  final bool emailAutomationEnabled;

  const Plan({
    required this.organizationId,
    required this.organizationName,
    this.startedAt,
    required this.expiredAt,
    this.hasExpiry = false,
    this.isTrial = false,
    this.planName = '',
    this.maxUsers = 5,
    this.shopifyEnabled = false,
    this.facebookEnabled = false,
    this.indiamartEnabled = false,
    this.whatsappEnabled = false,
    this.billingEnabled = false,
    this.emailAutomationEnabled = false,
  });

  // endDate kept as an alias so existing UI code still works
  DateTime get endDate => expiredAt;

  /// The expiry day as a local calendar date (time-of-day stripped).
  ///
  /// The API sends `expired_at` as an instant — usually midnight of the expiry
  /// day — and may send it in UTC. We compare at day granularity in local time
  /// so the plan stays active for the WHOLE expiry day, matching how the date
  /// reads to the user and to the web app.
  DateTime get _expiryLocalDate {
    final local = expiredAt.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  DateTime get _todayLocalDate {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// True only when we have a real expiry date AND its calendar day has fully
  /// passed. A plan that expires "today" is still active today.
  /// Fails open (returns false) when expiry is unknown, so a missing/garbled
  /// plan response never blocks access to the CRM.
  bool get isExpired => hasExpiry && _todayLocalDate.isAfter(_expiryLocalDate);

  /// Whole calendar days until expiry: 0 = expires today, negative = already
  /// past. Day-granularity so it never truncates a partial day to "0".
  int get daysRemaining => _expiryLocalDate.difference(_todayLocalDate).inDays;

  /// Variable headline for the expiry paywall — trial vs paid subscription.
  String get expiryTitle {
    if (isTrial) return 'Your 15-Day Free Trial Has Ended';
    if (planName.isNotEmpty) return 'Your ${_titleCase(planName)} Plan Has Expired';
    return 'Your Subscription Has Ended';
  }

  /// Supporting line under the headline.
  String get expirySubtitle =>
      'To continue using OceanCRM, please select a plan below and complete payment.';

  static String _titleCase(String s) => s.isEmpty
      ? s
      : s
          .split(RegExp(r'[\s_]+'))
          .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
          .join(' ');

  static bool _featureEnabled(dynamic featureMap) {
    if (featureMap is Map) return featureMap['enabled'] == true;
    return false;
  }

  factory Plan.fromJson(Map<String, dynamic> json) {
    final expiredRaw = json['expired_at']?.toString() ?? '';
    final parsedExpiry = DateTime.tryParse(expiredRaw);
    final startedAt = json['started_at'] != null
        ? DateTime.tryParse(json['started_at'].toString())
        : null;

    return Plan(
      organizationId: (json['organization_id'] ?? '').toString(),
      organizationName: (json['organization_name'] ?? '').toString(),
      startedAt: startedAt,
      expiredAt: parsedExpiry ?? DateTime(2000),
      hasExpiry: parsedExpiry != null,
      isTrial: _parseTrial(json, startedAt, parsedExpiry),
      planName: _parsePlanName(json),
      maxUsers: _toInt(json['max_users'], fallback: 5),
      shopifyEnabled: _featureEnabled(json['shopify']),
      facebookEnabled: _featureEnabled(json['facebook']),
      indiamartEnabled: _featureEnabled(json['indiamart']),
      whatsappEnabled: _featureEnabled(json['whatsapp']),
      billingEnabled: _featureEnabled(json['billingmodule']),
      emailAutomationEnabled: _featureEnabled(json['emailautomation']),
    );
  }

  /// Trial detection. PlanResponse has no `is_trial` flag, but it carries
  /// `upgrade_history` / `admin_upgrade_history`: an org that has ever upgraded
  /// has paid, so it's a real subscription; an empty history means the org is
  /// still on the free trial. Falls back to a short start→expiry window when the
  /// history fields are absent.
  static bool _parseTrial(
      Map<String, dynamic> json, DateTime? startedAt, DateTime? expiredAt) {
    // Explicit flag, if a future API adds one.
    for (final k in ['is_trial', 'trial', 'is_free_trial', 'on_trial']) {
      final v = json[k];
      if (v is bool) return v;
      if (v is String) return v.toLowerCase() == 'true';
    }
    final upg = json['upgrade_history'];
    final adminUpg = json['admin_upgrade_history'];
    final hasHistoryField = upg is List || adminUpg is List;
    if (hasHistoryField) {
      final hasUpgraded = (upg is List && upg.isNotEmpty) ||
          (adminUpg is List && adminUpg.isNotEmpty);
      return !hasUpgraded;
    }
    // Fallback heuristic: a ~15-day window implies the free trial.
    if (startedAt != null && expiredAt != null) {
      final days = expiredAt.difference(startedAt).inDays;
      if (days > 0 && days <= 20) return true;
    }
    return false;
  }

  /// Plan tier name if the API ever exposes one (PlanResponse currently doesn't,
  /// so this stays empty and the headline reads "Your Subscription Has Ended").
  static String _parsePlanName(Map<String, dynamic> json) {
    for (final k in ['plan_name', 'tier', 'plan_type']) {
      final v = json[k];
      if (v is String && v.isNotEmpty && v.toLowerCase() != 'trial') {
        return v;
      }
    }
    return '';
  }

  static int _toInt(dynamic v, {int fallback = 0}) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? fallback;
  }
}

class Integration {
  final String id;
  final String name;
  final bool isActive;

  const Integration({
    required this.id,
    required this.name,
    required this.isActive,
  });
}
