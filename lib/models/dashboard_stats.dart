class DashboardStats {
  final int totalLeads;
  final double totalLeadsChange;

  final int openDeals; // open_leads in API
  final double openDealsChange;

  final int wonDeals; // won_leads in API
  final double wonDealsChange;

  final double pipelineValue;
  final double pipelineValueChange;

  final double conversionRate;
  final double conversionRateChange;

  final double avgDealSize;
  final double avgDealSizeChange;

  const DashboardStats({
    required this.totalLeads,
    required this.totalLeadsChange,
    required this.openDeals,
    required this.openDealsChange,
    required this.wonDeals,
    required this.wonDealsChange,
    required this.pipelineValue,
    required this.pipelineValueChange,
    required this.conversionRate,
    required this.conversionRateChange,
    required this.avgDealSize,
    required this.avgDealSizeChange,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    // API returns nested structure: { all_time, current_30d, previous_30d }
    // We use current_30d and previous_30d to show "vs last 30 days" changes
    final current30d = _parseSection(json['current_30d']);
    final previous30d = _parseSection(json['previous_30d']);

    // Calculate change percentages: ((current - previous) / previous) * 100
    final totalLeadsChange = _calculateChange(current30d['total_leads'] as int, previous30d['total_leads'] as int);
    final openDealsChange = _calculateChange(current30d['open_leads'] as int, previous30d['open_leads'] as int);
    final wonDealsChange = _calculateChange(current30d['won_leads'] as int, previous30d['won_leads'] as int);
    final pipelineValueChange = _calculateChange(
      (current30d['pipeline_value'] as double).toInt(),
      (previous30d['pipeline_value'] as double).toInt(),
    );

    // Calculate conversion rate: (won_leads / total_leads) * 100
    final current30dTotalLeads = current30d['total_leads'] as int;
    final current30dWonLeads = current30d['won_leads'] as int;
    final conversionRate = current30dTotalLeads > 0
        ? (current30dWonLeads / current30dTotalLeads) * 100
        : 0.0;

    final previous30dTotalLeads = previous30d['total_leads'] as int;
    final previous30dWonLeads = previous30d['won_leads'] as int;
    final previousConversionRate = previous30dTotalLeads > 0
        ? (previous30dWonLeads / previous30dTotalLeads) * 100
        : 0.0;
    final conversionRateChange = _calculateChange(
      conversionRate.toInt(),
      previousConversionRate.toInt(),
    );

    return DashboardStats(
      totalLeads: current30d['total_leads'] as int,
      totalLeadsChange: totalLeadsChange,
      openDeals: current30d['open_leads'] as int,
      openDealsChange: openDealsChange,
      wonDeals: current30d['won_leads'] as int,
      wonDealsChange: wonDealsChange,
      pipelineValue: current30d['pipeline_value'] as double,
      pipelineValueChange: pipelineValueChange,
      conversionRate: conversionRate,
      conversionRateChange: conversionRateChange,
      avgDealSize: current30d['avg_deal_size'] as double,
      avgDealSizeChange: _calculateChange(
        (current30d['avg_deal_size'] as double).toInt(),
        (previous30d['avg_deal_size'] as double).toInt(),
      ),
    );
  }

  /// Parse a period section (all_time, current_30d, previous_30d) from the API response
  static Map<String, dynamic> _parseSection(dynamic section) {
    if (section == null || section is! Map) {
      return {
        'total_leads': 0,
        'open_leads': 0,
        'won_leads': 0,
        'pipeline_value': 0.0,
        'avg_deal_size': 0.0,
      };
    }
    return {
      'total_leads': _parseInt(section['total_leads']),
      'open_leads': _parseInt(section['open_leads']),
      'won_leads': _parseInt(section['won_leads']),
      'pipeline_value': _parseDouble(section['pipeline_value']),
      'avg_deal_size': _parseDouble(section['avg_deal_size']),
    };
  }

  /// Calculate percentage change: ((current - previous) / previous) * 100
  /// Handles zero division gracefully
  static double _calculateChange(int current, int previous) {
    if (previous == 0) {
      return current > 0 ? 100.0 : 0.0; // 100% increase if from 0 to non-zero
    }
    return ((current - previous) / previous) * 100;
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}
