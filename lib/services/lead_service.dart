import 'package:dio/dio.dart';
import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../models/lead.dart';
import '../models/paginated_response.dart';
import '../models/lead_field_settings.dart';

/// Service layer for lead CRUD and supporting resource operations.
class LeadService {
  final ApiClient _client = ApiClient();

  // ── Read Operations ──────────────────────────────────────────────

  /// Fetch paginated list of leads with optional filters.
  Future<PaginatedResponse<Lead>> getLeads({
    int page = 1,
    int pageSize = 20,
    String? query,
    String? stage,
    String sortBy = 'created_at',
    String sortOrder = 'desc',
  }) async {
    try {
      final response = await _client.dio.get(
        ApiConstants.leads,
        queryParameters: {
          'page': page,
          'page_size': pageSize,
          if (query != null && query.isNotEmpty) 'q': query,
          if (stage != null && stage.isNotEmpty) 'stage': stage,
          'sort_by': sortBy,
          'sort_order': sortOrder,
        },
      );

      return PaginatedResponse<Lead>.fromJson(
        response.data,
        (json) => Lead.fromJson(json),
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Fetch a single lead by ID.
  Future<Lead> getLeadById(String id) async {
    try {
      final response = await _client.dio.get(ApiConstants.leadById(id));
      return Lead.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ── Write Operations ─────────────────────────────────────────────

  /// Create a new lead.
  Future<Lead> createLead(CreateLeadRequest request) async {
    try {
      final response = await _client.dio.post(
        ApiConstants.leads,
        data: request.toJson(),
      );
      return Lead.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Update an existing lead.
  Future<Lead> updateLead(String id, UpdateLeadRequest request) async {
    try {
      final response = await _client.dio.put(
        ApiConstants.leadById(id),
        data: request.toJson(),
      );
      return Lead.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Delete a lead by ID.
  Future<void> deleteLead(String id) async {
    try {
      await _client.dio.delete(ApiConstants.leadById(id));
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ── Supporting Resources ─────────────────────────────────────────

  /// Fetch all lead stages for the organization.
  Future<List<LeadStage>> getLeadStages() async {
    try {
      final response = await _client.dio.get(ApiConstants.leadStages);
      return (response.data as List<dynamic>)
          .map((e) => LeadStage.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.order.compareTo(b.order));
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Fetch paginated products.
  Future<List<ProductItem>> getProducts() async {
    try {
      final response = await _client.dio.get(
        ApiConstants.products,
        queryParameters: {'page_size': 500},
      );
      return (response.data['items'] as List<dynamic>)
          .map((e) => ProductItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Fetch paginated sources.
  Future<List<SourceItem>> getSources() async {
    try {
      final response = await _client.dio.get(
        ApiConstants.sources,
        queryParameters: {'page_size': 500},
      );
      return (response.data['items'] as List<dynamic>)
          .map((e) => SourceItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Fetch custom field settings for leads.
  Future<LeadFieldSettings> getLeadFieldSettings() async {
    try {
      final response = await _client.dio.get(ApiConstants.leadSettings);
      return LeadFieldSettings.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<UserDetail>> getUsers() async {
    try {
      final response = await _client.dio.get(ApiConstants.users);
      return (response.data as List<dynamic>)
          .map((e) => UserDetail.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ── Error Handling ───────────────────────────────────────────────

  String _handleError(DioException e) {
    if (e.response?.statusCode == 401) {
      return 'Session expired. Please log in again.';
    }
    if (e.response?.statusCode == 404) {
      return 'Lead not found.';
    }
    if (e.response?.statusCode == 422) {
      final detail = e.response?.data?['detail'];
      if (detail is String) return detail;
      if (detail is List && detail.isNotEmpty) {
        return detail.first['msg'] ?? 'Validation error';
      }
      return 'Validation error';
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Connection timed out. Please check your internet.';
    }
    if (e.type == DioExceptionType.connectionError) {
      return 'No internet connection.';
    }
    return e.response?.data?['detail']?.toString() ?? 'Something went wrong';
  }
}
