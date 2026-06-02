import 'package:dio/dio.dart';

import '../core/network/api_client.dart';

class DashboardService {
  final ApiClient _client = ApiClient();

  Future<int> getLeadCount() async {
    try {
      final response = await _client.dio.get('/v1/lead/count');
      return response.data['total_count'] ?? 0;
    } on DioException {
      // Return 0 on error, or you can throw and handle in UI
      return 0;
    } catch (_) {
      return 0;
    }
  }
}
