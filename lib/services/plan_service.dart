import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/config/environment_service.dart';
import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../models/plan.dart';

class PlanService {
  final ApiClient _client = ApiClient();

  Future<({Plan? plan, List<Integration> integrations})> getPlanAndIntegrations() async {
    final results = await Future.wait([
      _fetchPlan(),
      _fetchShopify(),
      _fetchIndiamart(),
      _fetchMeta(),
      _fetchCalendar(),
    ]);

    final plan = results[0] as Plan?;
    final shopify = results[1] as List<Integration>;
    final indiamart = results[2] as List<Integration>;
    final meta = results[3] as List<Integration>;
    final calendar = results[4] as List<Integration>;

    final integrations = [...shopify, ...indiamart, ...meta, ...calendar];
    return (plan: plan, integrations: integrations);
  }

  /// Fetch just the org's current plan (used by the expiry gate).
  Future<Plan?> fetchPlan() => _fetchPlan();

  Future<Plan?> _fetchPlan() async {
    try {
      final response = await _client.dio.get(ApiConstants.orgPlans);
      final data = response.data;
      if (kDebugMode) debugPrint('[PlanService] org/plans raw: $data');

      List<dynamic> list = [];
      if (data is List) {
        list = data;
      } else if (data is Map) {
        final inner = data['data'] ?? data['plans'] ?? data['items'];
        if (inner is List) list = inner;
      }

      final plans = list
          .whereType<Map<String, dynamic>>()
          .map(Plan.fromJson)
          .toList();
      if (plans.isEmpty) return null;

      // /v1/org/plans/ returns one plan per org the user belongs to. Pick the
      // plan for the CURRENTLY ACTIVE org — not list.first, which can be a
      // different (expired) org and would wrongly trigger the paywall while the
      // web app shows the active org's far-future expiry.
      final activeOrgId = await EnvironmentService.instance.getOrgId();
      if (activeOrgId != null && activeOrgId.isNotEmpty) {
        for (final p in plans) {
          if (p.organizationId == activeOrgId) return p;
        }
      }

      // No org match (stale/unknown org id): fall back to the plan with the
      // latest expiry so any still-active plan keeps the user out of the
      // paywall, rather than blindly taking the first element.
      plans.sort((a, b) => b.expiredAt.compareTo(a.expiredAt));
      return plans.first;
    } on DioException catch (e) {
      if (kDebugMode) debugPrint('[PlanService] /v1/org/plans/ error: ${e.response?.statusCode} ${e.message}');
    } catch (e) {
      if (kDebugMode) debugPrint('[PlanService] /v1/org/plans/ error: $e');
    }
    return null;
  }

  Future<List<Integration>> _fetchShopify() async {
    try {
      final response = await _client.dio.get(ApiConstants.shopifyAccounts);
      final data = response.data;
      if (kDebugMode) debugPrint('[PlanService] shopify raw: $data');

      final list = _asList(data);
      return list
          .whereType<Map<String, dynamic>>()
          .where((m) => m['is_connected'] != false)
          .map((m) => Integration(
                id: (m['id'] ?? '').toString(),
                name: 'Shopify${m['shop_domain'] != null ? ': ${m['shop_domain']}' : ''}',
                isActive: true,
              ))
          .toList();
    } on DioException catch (e) {
      if (kDebugMode) debugPrint('[PlanService] shopify error: ${e.response?.statusCode}');
    } catch (e) {
      if (kDebugMode) debugPrint('[PlanService] shopify error: $e');
    }
    return [];
  }

  Future<List<Integration>> _fetchIndiamart() async {
    try {
      final response = await _client.dio.get(ApiConstants.indiamartAccounts);
      final data = response.data;
      if (kDebugMode) debugPrint('[PlanService] indiamart raw: $data');

      final list = _asList(data);
      return list
          .whereType<Map<String, dynamic>>()
          .map((m) => Integration(
                id: (m['id'] ?? '').toString(),
                name: 'IndiaMart${m['name'] != null && (m['name'] as String).isNotEmpty ? ': ${m['name']}' : ''}',
                isActive: true,
              ))
          .toList();
    } on DioException catch (e) {
      if (kDebugMode) debugPrint('[PlanService] indiamart error: ${e.response?.statusCode}');
    } catch (e) {
      if (kDebugMode) debugPrint('[PlanService] indiamart error: $e');
    }
    return [];
  }

  Future<List<Integration>> _fetchMeta() async {
    try {
      final response = await _client.dio.get(ApiConstants.metaAccounts);
      final data = response.data;
      if (kDebugMode) debugPrint('[PlanService] meta raw: $data');

      final list = _asList(data);
      return list
          .whereType<Map<String, dynamic>>()
          .map((m) => Integration(
                id: (m['id'] ?? '').toString(),
                name: 'Meta${m['page_name'] != null && (m['page_name'] as String).isNotEmpty ? ': ${m['page_name']}' : ''}',
                isActive: true,
              ))
          .toList();
    } on DioException catch (e) {
      if (kDebugMode) debugPrint('[PlanService] meta error: ${e.response?.statusCode}');
    } catch (e) {
      if (kDebugMode) debugPrint('[PlanService] meta error: $e');
    }
    return [];
  }

  Future<List<Integration>> _fetchCalendar() async {
    try {
      final response = await _client.dio.get(ApiConstants.calendarStatus);
      final data = response.data;
      if (kDebugMode) debugPrint('[PlanService] calendar raw: $data');

      if (data is Map<String, dynamic> && data['connected'] == true) {
        final email = data['email']?.toString() ?? '';
        return [
          Integration(
            id: 'calendar',
            name: 'Google Calendar${email.isNotEmpty ? ': $email' : ''}',
            isActive: true,
          ),
        ];
      }
    } on DioException catch (e) {
      if (kDebugMode) debugPrint('[PlanService] calendar error: ${e.response?.statusCode}');
    } catch (e) {
      if (kDebugMode) debugPrint('[PlanService] calendar error: $e');
    }
    return [];
  }

  List<dynamic> _asList(dynamic data) {
    if (data is List) return data;
    if (data is Map) {
      final inner = data['data'] ?? data['items'] ?? data['results'];
      if (inner is List) return inner;
    }
    return [];
  }
}
