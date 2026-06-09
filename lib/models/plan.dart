class Plan {
  final String organizationId;
  final String organizationName;
  final DateTime? startedAt;
  final DateTime expiredAt;

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
    this.shopifyEnabled = false,
    this.facebookEnabled = false,
    this.indiamartEnabled = false,
    this.whatsappEnabled = false,
    this.billingEnabled = false,
    this.emailAutomationEnabled = false,
  });

  // endDate kept as an alias so existing UI code still works
  DateTime get endDate => expiredAt;

  static bool _featureEnabled(dynamic featureMap) {
    if (featureMap is Map) return featureMap['enabled'] == true;
    return false;
  }

  factory Plan.fromJson(Map<String, dynamic> json) {
    final expiredRaw = json['expired_at']?.toString() ?? '';
    final expiredAt = DateTime.tryParse(expiredRaw) ?? DateTime(2000);

    return Plan(
      organizationId: (json['organization_id'] ?? '').toString(),
      organizationName: (json['organization_name'] ?? '').toString(),
      startedAt: json['started_at'] != null
          ? DateTime.tryParse(json['started_at'].toString())
          : null,
      expiredAt: expiredAt,
      shopifyEnabled: _featureEnabled(json['shopify']),
      facebookEnabled: _featureEnabled(json['facebook']),
      indiamartEnabled: _featureEnabled(json['indiamart']),
      whatsappEnabled: _featureEnabled(json['whatsapp']),
      billingEnabled: _featureEnabled(json['billingmodule']),
      emailAutomationEnabled: _featureEnabled(json['emailautomation']),
    );
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
