class DashboardStats {
  final int totalLeads;
  final double totalLeadsChange;
  final int previousTotalLeads;

  final int openDeals;
  final double openDealsChange;
  final int previousOpenDeals;

  final int wonDeals;
  final double wonDealsChange;
  final int previousWonDeals;

  final double pipelineValue;
  final double pipelineValueChange;
  final double previousPipelineValue;

  final double conversionRate;
  final double conversionRateChange;
  final double previousConversionRate;

  final double avgDealSize;
  final double avgDealSizeChange;
  final double previousAvgDealSize;

  const DashboardStats({
    required this.totalLeads,
    required this.totalLeadsChange,
    this.previousTotalLeads = 0,
    required this.openDeals,
    required this.openDealsChange,
    this.previousOpenDeals = 0,
    required this.wonDeals,
    required this.wonDealsChange,
    this.previousWonDeals = 0,
    required this.pipelineValue,
    required this.pipelineValueChange,
    this.previousPipelineValue = 0,
    required this.conversionRate,
    required this.conversionRateChange,
    this.previousConversionRate = 0,
    required this.avgDealSize,
    required this.avgDealSizeChange,
    this.previousAvgDealSize = 0,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    final current = _parseSection(json['current_30d']);
    final previous = _parseSection(json['previous_30d']);

    final currentTotal = current['total_leads'] as int;
    final currentWon = current['won_leads'] as int;
    final previousTotal = previous['total_leads'] as int;
    final previousWon = previous['won_leads'] as int;

    final conversionRate = currentTotal > 0 ? (currentWon / currentTotal) * 100 : 0.0;
    final prevConvRate = previousTotal > 0 ? (previousWon / previousTotal) * 100 : 0.0;

    return DashboardStats(
      totalLeads: currentTotal,
      totalLeadsChange: _change(currentTotal, previousTotal),
      previousTotalLeads: previousTotal,
      openDeals: current['open_leads'] as int,
      openDealsChange: _change(current['open_leads'] as int, previous['open_leads'] as int),
      previousOpenDeals: previous['open_leads'] as int,
      wonDeals: currentWon,
      wonDealsChange: _change(currentWon, previousWon),
      previousWonDeals: previousWon,
      pipelineValue: current['pipeline_value'] as double,
      pipelineValueChange: _change(
        (current['pipeline_value'] as double).toInt(),
        (previous['pipeline_value'] as double).toInt(),
      ),
      previousPipelineValue: previous['pipeline_value'] as double,
      conversionRate: conversionRate,
      conversionRateChange: _change(conversionRate.toInt(), prevConvRate.toInt()),
      previousConversionRate: prevConvRate,
      avgDealSize: current['avg_deal_size'] as double,
      avgDealSizeChange: _change(
        (current['avg_deal_size'] as double).toInt(),
        (previous['avg_deal_size'] as double).toInt(),
      ),
      previousAvgDealSize: previous['avg_deal_size'] as double,
    );
  }

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
      'total_leads': _int(section['total_leads']),
      'open_leads': _int(section['open_leads']),
      'won_leads': _int(section['won_leads']),
      'pipeline_value': _dbl(section['pipeline_value']),
      'avg_deal_size': _dbl(section['avg_deal_size']),
    };
  }

  static double _change(int current, int previous) {
    if (previous == 0) return current > 0 ? 100.0 : 0.0;
    return ((current - previous) / previous) * 100;
  }

  static int _int(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  static double _dbl(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }
}
