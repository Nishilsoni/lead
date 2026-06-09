import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/network/api_client.dart';
import '../core/constants/api_constants.dart';
import '../models/dashboard_stats.dart';

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
