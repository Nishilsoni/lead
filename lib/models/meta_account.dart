// Meta (Facebook) ad account, campaign and insight models matching the
// OceanCRM API schema (/v1/meta/ad-account*).

/// A Facebook ad account connected to the org (backend record).
class MetaAdAccount {
  /// Internal backend UUID — used for all /ad-account/{id} routes.
  final String accountId;

  /// Facebook's own ad account id, e.g. "act_1378844719934057".
  final String adAccountId;
  final String accountName;
  final String currency;
  final String timezone;

  const MetaAdAccount({
    required this.accountId,
    required this.adAccountId,
    required this.accountName,
    required this.currency,
    required this.timezone,
  });

  factory MetaAdAccount.fromJson(Map<String, dynamic> json) {
    return MetaAdAccount(
      accountId: (json['account_id'] ?? json['id'] ?? '').toString(),
      adAccountId: (json['ad_account_id'] ?? json['act_id'] ?? '').toString(),
      accountName:
          (json['account_name'] ?? json['name'] ?? 'Untitled account').toString(),
      currency: (json['currency'] ?? '').toString(),
      timezone:
          (json['timezone'] ?? json['timezone_name'] ?? json['time_zone'] ?? '')
              .toString(),
    );
  }
}

/// Aggregated campaign metrics for the whole ad account.
class CampaignSummary {
  final double totalSpend;
  final int totalImpressions;
  final int totalClicks;
  final String currency;

  const CampaignSummary({
    this.totalSpend = 0,
    this.totalImpressions = 0,
    this.totalClicks = 0,
    this.currency = '',
  });

  /// Click-through rate across the account as a percentage.
  double get ctr =>
      totalImpressions == 0 ? 0 : (totalClicks / totalImpressions) * 100;

  factory CampaignSummary.fromJson(Map<String, dynamic> json) {
    return CampaignSummary(
      totalSpend: _toDouble(json['total_spend']),
      totalImpressions: _toInt(json['total_impressions']),
      totalClicks: _toInt(json['total_clicks']),
      currency: (json['currency'] ?? '').toString(),
    );
  }
}

/// Per-campaign performance metrics.
class CampaignInsights {
  final int impressions;
  final int clicks;
  final double ctr;
  final double spend;

  const CampaignInsights({
    this.impressions = 0,
    this.clicks = 0,
    this.ctr = 0,
    this.spend = 0,
  });

  factory CampaignInsights.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const CampaignInsights();
    return CampaignInsights(
      impressions: _toInt(json['impressions']),
      clicks: _toInt(json['clicks']),
      ctr: _toDouble(json['ctr']),
      spend: _toDouble(json['spend']),
    );
  }
}

/// A single Facebook campaign with its insights.
class MetaCampaign {
  final String campaignId;
  final String campaignName;
  final String status;
  final CampaignInsights insights;

  const MetaCampaign({
    required this.campaignId,
    required this.campaignName,
    this.status = '',
    this.insights = const CampaignInsights(),
  });

  factory MetaCampaign.fromJson(Map<String, dynamic> json) {
    return MetaCampaign(
      campaignId: (json['campaign_id'] ?? json['id'] ?? '').toString(),
      campaignName:
          (json['campaign_name'] ?? json['name'] ?? 'Untitled campaign')
              .toString(),
      status: (json['status'] ?? json['effective_status'] ?? '').toString(),
      insights: CampaignInsights.fromJson(
          json['insights'] as Map<String, dynamic>?),
    );
  }
}

/// Result of GET /ad-account/{id}/campaigns — campaigns + account summary.
class CampaignListResult {
  final List<MetaCampaign> campaigns;
  final CampaignSummary summary;

  const CampaignListResult({
    this.campaigns = const [],
    this.summary = const CampaignSummary(),
  });

  factory CampaignListResult.fromJson(Map<String, dynamic> json) {
    final rawCampaigns = json['campaigns'];
    return CampaignListResult(
      campaigns: rawCampaigns is List
          ? rawCampaigns
              .whereType<Map<String, dynamic>>()
              .map(MetaCampaign.fromJson)
              .toList()
          : const [],
      summary: json['summary'] is Map<String, dynamic>
          ? CampaignSummary.fromJson(json['summary'] as Map<String, dynamic>)
          : const CampaignSummary(),
    );
  }
}

/// An ad account the logged-in Facebook user can choose to connect, fetched
/// from the Graph API (/me/adaccounts) during the Add Ad Account flow.
class FacebookAdAccountOption {
  /// Facebook ad account id, e.g. "act_2013608959546852".
  final String adAccountId;
  final String name;
  final String currency;
  final String timezone;

  /// Facebook account_status: 1 = ACTIVE, others = disabled/pending/etc.
  final int accountStatus;

  const FacebookAdAccountOption({
    required this.adAccountId,
    required this.name,
    required this.currency,
    required this.timezone,
    required this.accountStatus,
  });

  bool get isActive => accountStatus == 1;

  factory FacebookAdAccountOption.fromJson(Map<String, dynamic> json) {
    return FacebookAdAccountOption(
      adAccountId: (json['id'] ?? '').toString(),
      name: (json['name'] ?? 'Untitled account').toString(),
      currency: (json['currency'] ?? '').toString(),
      timezone: (json['timezone_name'] ?? '').toString(),
      accountStatus: _toInt(json['account_status']),
    );
  }
}

// ── Parsing helpers (the Graph/CRM APIs mix strings & numbers) ───────────────

int _toInt(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? 0;
}

double _toDouble(dynamic v) {
  if (v == null) return 0;
  if (v is double) return v;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}
