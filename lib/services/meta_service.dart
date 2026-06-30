import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/constants/api_constants.dart';
import '../core/constants/facebook_config.dart';
import '../core/network/api_client.dart';
import '../models/facebook_lead_import.dart';
import '../models/meta_account.dart';

/// Service for Meta (Facebook) ad accounts, campaigns and the connect flow.
///
/// Backend calls go through the authenticated [ApiClient]; the Facebook Graph
/// API call (listing the user's selectable ad accounts) uses a plain Dio so our
/// auth headers and base URL aren't applied to graph.facebook.com.
class MetaService {
  final ApiClient _client = ApiClient();
  final Dio _graphDio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 20),
  ));

  // ── Backend: connected ad accounts ─────────────────────────────────

  /// List ad accounts connected to the active org.
  Future<List<MetaAdAccount>> getAdAccounts() async {
    try {
      final response = await _client.dio.get(ApiConstants.metaAdAccounts);
      return _asList(response.data)
          .whereType<Map<String, dynamic>>()
          .map(MetaAdAccount.fromJson)
          .toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Connect a new ad account using a Facebook user token + selected account id.
  Future<MetaAdAccount> addAdAccount({
    required String userToken,
    required String adAccountId,
  }) async {
    try {
      final response = await _client.dio.post(
        ApiConstants.metaAdAccounts,
        data: {'user_token': userToken, 'ad_account_id': adAccountId},
      );
      final data = response.data;
      if (data is Map<String, dynamic>) return MetaAdAccount.fromJson(data);
      // Some backends return the refreshed list; fall back to a minimal record.
      return MetaAdAccount(
        accountId: '',
        adAccountId: adAccountId,
        accountName: '',
        currency: '',
        timezone: '',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Disconnect an ad account by its internal backend id.
  Future<void> deleteAdAccount(String accountId) async {
    try {
      await _client.dio.delete(ApiConstants.metaAdAccountById(accountId));
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Refresh stored Facebook tokens for all connected accounts.
  Future<String> refreshTokens() async {
    try {
      final response = await _client.dio.post(ApiConstants.metaRefreshTokens);
      final data = response.data;
      if (data is Map && data['message'] != null) {
        return data['message'].toString();
      }
      return 'Tokens refreshed';
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ── Backend: campaigns + insights ──────────────────────────────────

  /// Fetch campaigns with per-campaign metrics + an account-level summary.
  Future<CampaignListResult> getCampaigns(String accountId) async {
    try {
      final response =
          await _client.dio.get(ApiConstants.metaAdAccountCampaigns(accountId));
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return CampaignListResult.fromJson(data);
      }
      // A bare list of campaigns with no summary.
      if (data is List) {
        return CampaignListResult.fromJson({'campaigns': data});
      }
      return const CampaignListResult();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ── Backend: Facebook Lead Ads auto-import connections ─────────────

  /// List saved page+form auto-import connections for the active org.
  ///
  /// These are the Facebook page/lead-form connections returned by
  /// GET /v1/meta/account (Administration → Facebook).
  Future<List<AutoImportAccount>> getAutoImportAccounts() async {
    try {
      final response = await _client.dio.get(ApiConstants.metaAccounts);
      return _asList(response.data)
          .whereType<Map<String, dynamic>>()
          .map(AutoImportAccount.fromJson)
          .toList();
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 404 || code == 405 || code == 501) return const [];
      throw _handleError(e);
    }
  }

  /// Save a new page+form auto-import connection.
  Future<AutoImportAccount> connectAutoImport({
    required String userToken,
    required FacebookPage page,
    required FacebookLeadForm form,
  }) async {
    try {
      final response = await _client.dio.post(
        ApiConstants.facebookLeadImport,
        data: {
          'user_token': userToken,
          'page_id': page.id,
          'page_name': page.name,
          'page_access_token': page.accessToken,
          'form_id': form.id,
          'form_name': form.name,
        },
      );
      final data = response.data;
      if (data is Map<String, dynamic>) return AutoImportAccount.fromJson(data);
      return AutoImportAccount(
        id: '',
        pageId: page.id,
        pageName: page.name,
        formId: form.id,
        formName: form.name,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Delete a saved auto-import connection by its backend id.
  Future<void> deleteAutoImport(String id) async {
    try {
      await _client.dio.delete(ApiConstants.metaAccountById(id));
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ── Facebook Graph: pages & lead forms during connect ──────────────

  /// List the Facebook pages the logged-in user manages.
  Future<List<FacebookPage>> fetchPages(String userToken) async {
    try {
      final response = await _graphDio.getUri(FacebookConfig.pagesUrl(userToken));
      return _graphData(response.data)
          .map(FacebookPage.fromJson)
          .toList();
    } on DioException catch (e) {
      throw _graphError(e, 'Could not load your Facebook pages.');
    }
  }

  /// List the Lead Ads forms on a page (needs the page access token).
  Future<List<FacebookLeadForm>> fetchLeadForms(
      String pageId, String pageAccessToken) async {
    try {
      final response = await _graphDio
          .getUri(FacebookConfig.leadFormsUrl(pageId, pageAccessToken));
      return _graphData(response.data)
          .map(FacebookLeadForm.fromJson)
          .toList();
    } on DioException catch (e) {
      throw _graphError(e, 'Could not load lead forms for this page.');
    }
  }

  // ── Facebook Graph: selectable ad accounts during connect ──────────

  /// List the ad accounts the just-logged-in Facebook user can connect.
  Future<List<FacebookAdAccountOption>> fetchAvailableAdAccounts(
      String userToken) async {
    try {
      final response =
          await _graphDio.getUri(FacebookConfig.adAccountsUrl(userToken));
      return _graphData(response.data)
          .map(FacebookAdAccountOption.fromJson)
          .toList();
    } on DioException catch (e) {
      throw _graphError(e, 'Could not load Facebook ad accounts.');
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────

  /// Pull the `data` array out of a Facebook Graph paged response.
  List<Map<String, dynamic>> _graphData(dynamic data) {
    final list = (data is Map && data['data'] is List)
        ? data['data'] as List
        : const [];
    return list.whereType<Map<String, dynamic>>().toList();
  }

  /// Turn a Graph API DioException into a readable message (prefers FB's own).
  String _graphError(DioException e, String fallback) {
    if (kDebugMode) {
      debugPrint('[MetaService] graph error: ${e.response?.data}');
    }
    final fbError = e.response?.data;
    if (fbError is Map && fbError['error'] is Map) {
      return fbError['error']['message']?.toString() ?? fallback;
    }
    if (e.type == DioExceptionType.connectionError) {
      return 'No internet connection.';
    }
    return '$fallback Please try again.';
  }

  List<dynamic> _asList(dynamic data) {
    if (data is List) return data;
    if (data is Map) {
      final inner = data['data'] ?? data['items'] ?? data['results'];
      if (inner is List) return inner;
    }
    return const [];
  }

  String _handleError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Connection timed out. Please check your internet.';
    }
    if (e.type == DioExceptionType.connectionError) {
      return 'No internet connection.';
    }
    final data = e.response?.data;
    if (data is Map) {
      final detail = data['detail'] ?? data['message'];
      if (detail is String) return detail;
      if (detail is List && detail.isNotEmpty) {
        final first = detail.first;
        if (first is Map && first['msg'] != null) return first['msg'].toString();
      }
    }
    return 'Something went wrong. Please try again.';
  }
}
