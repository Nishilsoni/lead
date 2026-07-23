import 'package:dio/dio.dart';
import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../models/permission.dart';
import 'admin_api_error.dart';

/// Reads the org's permission catalog — the flat `{ id, name }` list that the
/// role editor groups into its Module × Action matrix.
class PermissionService with AdminApiError {
  final ApiClient _client = ApiClient();

  Future<List<Permission>> getPermissions() async {
    try {
      final response = await _client.dio.get(ApiConstants.permissions);
      final data = response.data;
      final list = data is List ? data : const [];
      return list
          .whereType<Map>()
          .map((m) => Permission.fromJson(Map<String, dynamic>.from(m)))
          .where((p) => p.id != 0 && p.name.isNotEmpty)
          .toList();
    } on DioException catch (e) {
      throw humanizeError(e, subject: 'permission');
    }
  }
}
