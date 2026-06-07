import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../models/org.dart';

class OrgService {
  final ApiClient _client = ApiClient();

  /// Returns all orgs the logged-in user belongs to.
  ///
  /// IMPORTANT: x-org-id must NOT be sent for this call — it scopes the
  /// response to a single org. We explicitly override it to null here AND
  /// the interceptor also skips it for /org/current paths.
  Future<List<Org>> fetchOrgs() async {
    try {
      final response = await _client.dio.get(
        ApiConstants.currentOrg,
        options: Options(
          // Explicitly prevent x-org-id from being sent
          headers: {'x-org-id': null},
        ),
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
            '${orgs.map((o) => "${o.name}(${o.id})").join(", ")}');
      }

      return orgs;
    } catch (e) {
      if (kDebugMode) debugPrint('[OrgService] error: $e');
      return [];
    }
  }
}
