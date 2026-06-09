/// 30-day daily time-series data derived from the leads list endpoint.
/// Each list has exactly 30 entries (index 0 = 30 days ago, index 29 = today).
class DashboardChartData {
  final List<double> totalLeads;
  final List<double> openDeals;
  final List<double> wonDeals;
  final List<double> pipelineValue;
  final List<double> avgDealSize;
  final List<double> conversionRate;

  const DashboardChartData({
    required this.totalLeads,
    required this.openDeals,
    required this.wonDeals,
    required this.pipelineValue,
    required this.avgDealSize,
    required this.conversionRate,
  });

  static DashboardChartData empty() => DashboardChartData(
        totalLeads: List.filled(30, 0),
        openDeals: List.filled(30, 0),
        wonDeals: List.filled(30, 0),
        pipelineValue: List.filled(30, 0),
        avgDealSize: List.filled(30, 0),
        conversionRate: List.filled(30, 0),
      );
}
