import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../models/org.dart';

class OrgService {
  final ApiClient _client = ApiClient();

  /// Returns all orgs the logged-in user belongs to.
  /// Uses extra['skipOrgId'] = true so the interceptor never injects x-org-id.
  /// Sending x-org-id to this endpoint scopes the response to a single org.
  Future<List<Org>> fetchOrgs() async {
    try {
      final response = await _client.dio.get(
        ApiConstants.currentOrg,
        options: Options(extra: {'skipOrgId': true}),
      );
      final data = response.data;

      if (kDebugMode) debugPrint('[OrgService] raw: $data');

      List<dynamic> raw = [];
      if (data is List) {
        raw = data;
      } else if (data is Map) {
        if (data['items'] is List) {
          raw = data['items'] as List;
        } else if (data['data'] is List) {
          raw = data['data'] as List;
        } else if (data['organizations'] is List) {
          raw = data['organizations'] as List;
        }
      }

      final orgs = raw
          .whereType<Map<String, dynamic>>()
          .map(Org.fromJson)
          .where((o) => o.id.isNotEmpty)
          .toList();

      if (kDebugMode) {
        debugPrint('[OrgService] parsed ${orgs.length} orgs: '
            '${orgs.map((o) => '${o.name}(${o.id})').join(', ')}');
      }

      return orgs;
    } catch (e) {
      if (kDebugMode) debugPrint('[OrgService] error: $e');
      return [];
    }
  }
}
