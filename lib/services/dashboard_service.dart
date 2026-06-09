import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/network/api_client.dart';
import '../core/constants/api_constants.dart';
import '../models/dashboard_stats.dart';
import '../models/dashboard_chart_data.dart';
import '../models/lead.dart';

class DashboardService {
  final ApiClient _client = ApiClient();

  /// Fetch comprehensive dashboard KPI stats with all metrics and change percentages.
  /// Requires x-org-id header which is auto-injected by the interceptor.
  Future<DashboardStats> getStats() async {
    try {
      if (kDebugMode) debugPrint('[DashboardService] Fetching stats from ${ApiConstants.dashboardStats}');

      final response = await _client.dio.get(ApiConstants.dashboardStats);

      if (kDebugMode) {
        debugPrint('[DashboardService] Response status: ${response.statusCode}');
        debugPrint('[DashboardService] Response data: ${response.data}');
        debugPrint('[DashboardService] Response headers: ${response.headers}');
      }

      // Handle various response wrapper formats
      dynamic data = response.data;
      if (data is Map && data.containsKey('data')) {
        data = data['data'];
      }

      if (data == null || data is! Map) {
        if (kDebugMode) debugPrint('[DashboardService] Invalid response format, returning zeros');
        return _zeroStats();
      }

      final stats = DashboardStats.fromJson(data as Map<String, dynamic>);

      if (kDebugMode) {
        debugPrint('[DashboardService] Parsed stats:');
        debugPrint('  totalLeads: ${stats.totalLeads} (${stats.totalLeadsChange.toStringAsFixed(1)}%)');
        debugPrint('  openDeals: ${stats.openDeals} (${stats.openDealsChange.toStringAsFixed(1)}%)');
        debugPrint('  wonDeals: ${stats.wonDeals} (${stats.wonDealsChange.toStringAsFixed(1)}%)');
        debugPrint('  pipelineValue: ₹${stats.pipelineValue.toInt()} (${stats.pipelineValueChange.toStringAsFixed(1)}%)');
        debugPrint('  conversionRate: ${stats.conversionRate.toStringAsFixed(1)}% (${stats.conversionRateChange.toStringAsFixed(1)}%)');
        debugPrint('  avgDealSize: ₹${stats.avgDealSize.toInt()} (${stats.avgDealSizeChange.toStringAsFixed(1)}%)');
      }

      return stats;
    } on DioException catch (e) {
      if (kDebugMode) {
        debugPrint('[DashboardService] DioException: ${e.type}');
        debugPrint('[DashboardService] Status Code: ${e.response?.statusCode}');
        debugPrint('[DashboardService] Message: ${e.message}');
        debugPrint('[DashboardService] Response: ${e.response?.data}');
      }
      return _zeroStats();
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[DashboardService] Unexpected error: $e');
        debugPrint('[DashboardService] Stacktrace: $st');
      }
      return _zeroStats();
    }
  }

  /// Fetches all leads created in the last 30 days and buckets them by day
  /// to produce real time-series data for each KPI sparkline.
  Future<DashboardChartData> getChartData() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final since = today.subtract(const Duration(days: 29));

    try {
      final response = await _client.dio.get(
        ApiConstants.leads,
        queryParameters: {
          'since': since.toIso8601String(),
          'page_size': 500,
          'sort_by': 'created_at',
          'sort_order': 'asc',
        },
      );

      final raw = response.data;
      List<dynamic> items = [];
      if (raw is Map) {
        items = (raw['items'] ?? raw['data'] ?? raw['results'] ?? []) as List;
      } else if (raw is List) {
        items = raw;
      }

      // 30 buckets: index 0 = `since`, index 29 = today
      final buckets = List.generate(30, (_) => <Lead>[]);
      for (final item in items) {
        if (item is! Map<String, dynamic>) continue;
        final lead = Lead.fromJson(item);
        final leadDay = DateTime(lead.since.year, lead.since.month, lead.since.day);
        final idx = leadDay.difference(since).inDays;
        if (idx >= 0 && idx < 30) buckets[idx].add(lead);
      }

      final totalLeads = <double>[];
      final openDeals = <double>[];
      final wonDeals = <double>[];
      final pipelineValue = <double>[];
      final avgDealSize = <double>[];
      final conversionRate = <double>[];

      for (final bucket in buckets) {
        final total = bucket.length.toDouble();
        final won = bucket
            .where((l) => l.stage.toLowerCase() == 'won')
            .length
            .toDouble();
        final open = bucket
            .where((l) => !['won', 'lost'].contains(l.stage.toLowerCase()))
            .length
            .toDouble();
        final pipeline =
            bucket.fold(0.0, (sum, l) => sum + l.potential.toDouble());
        totalLeads.add(total);
        wonDeals.add(won);
        openDeals.add(open);
        pipelineValue.add(pipeline);
        avgDealSize.add(total > 0 ? pipeline / total : 0.0);
        conversionRate.add(total > 0 ? (won / total) * 100 : 0.0);
      }

      return DashboardChartData(
        totalLeads: totalLeads,
        openDeals: openDeals,
        wonDeals: wonDeals,
        pipelineValue: pipelineValue,
        avgDealSize: avgDealSize,
        conversionRate: conversionRate,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[DashboardService] chart data error: $e');
      return DashboardChartData.empty();
    }
  }

  static DashboardStats _zeroStats() {
    return const DashboardStats(
      totalLeads: 0,
      totalLeadsChange: 0,
      openDeals: 0,
      openDealsChange: 0,
      wonDeals: 0,
      wonDealsChange: 0,
      pipelineValue: 0,
      pipelineValueChange: 0,
      conversionRate: 0,
      conversionRateChange: 0,
      avgDealSize: 0,
      avgDealSizeChange: 0,
    );
  }
}
