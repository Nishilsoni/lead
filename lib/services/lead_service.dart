import 'dart:convert';
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

  /// Fetch all leads across pages and return UTF-8 CSV bytes for export.
  Future<List<int>> exportLeads() async {
    const pageSize = 200;
    final allLeads = <Lead>[];
    int page = 1;

    while (true) {
      final result = await getLeads(page: page, pageSize: pageSize);
      allLeads.addAll(result.items);
      if (!result.hasMore) break;
      page++;
    }

    return _buildCsvBytes(allLeads);
  }

  List<int> _buildCsvBytes(List<Lead> leads) {
    final buf = StringBuffer();
    buf.writeln(
      '"Business Name","Contact Person","Mobile","Email","Stage",'
      '"Potential Value","Assigned To","Tags","Source","City","Date"',
    );
    for (final lead in leads) {
      buf.writeln([
        _csvField(lead.displayName),
        _csvField(lead.contactPerson),
        _csvField(lead.business.mobile),
        _csvField(lead.business.email),
        _csvField(lead.stage),
        lead.potential.toString(),
        _csvField(lead.assignedUser?.name ?? ''),
        _csvField(lead.tags.join(', ')),
        _csvField(lead.source?.name ?? ''),
        _csvField(lead.business.city),
        '"${lead.since.toIso8601String().split('T').first}"',
      ].join(','));
    }
    return utf8.encode(buf.toString());
  }

  String _csvField(String v) => '"${v.replaceAll('"', '""')}"';

  /// Bulk-assign multiple leads to a user in one request.
  Future<void> bulkAssignLeads({
    required List<String> leadIds,
    required String? userId,
  }) async {
    try {
      await _client.dio.post(
        ApiConstants.leadBulkAssign,
        data: {'lead_ids': leadIds, 'assigned_to': userId},
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
  Future<List<LeadStage>> getLeadStages({String? section}) async {
    try {
      final response = await _client.dio.get(
        ApiConstants.leadStages,
        queryParameters: (section != null && section.isNotEmpty)
            ? {'section': section}
            : null,
      );
      final stages = _parseStages(response.data);
      // Ensure each stage carries its pipeline when we asked for a specific one.
      if (section != null && section.isNotEmpty) {
        return stages
            .map((s) => (s.section == null || s.section!.isEmpty)
                ? LeadStage(
                    id: s.id,
                    stage: s.stage,
                    order: s.order,
                    section: section)
                : s)
            .toList();
      }
      return stages;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Parse the stage list across the shapes the API may return:
  ///  • a flat list: `[{stage, order, section}, ...]`
  ///  • grouped by pipeline: `{"Inquiry Pipeline": [{stage, order}, ...], ...}`
  ///  • wrapped: `{"items": [...]}` or `{"stages": [...]}` or `{"data": [...]}`
  List<LeadStage> _parseStages(dynamic data) {
    final out = <LeadStage>[];

    void addFrom(dynamic list, String? section) {
      if (list is List) {
        for (final e in list) {
          if (e is Map<String, dynamic>) {
            final s = LeadStage.fromJson(e);
            out.add(section != null && (s.section == null || s.section!.isEmpty)
                ? LeadStage(
                    id: s.id, stage: s.stage, order: s.order, section: section)
                : s);
          } else if (e is String) {
            out.add(LeadStage(stage: e, order: out.length, section: section));
          }
        }
      }
    }

    if (data is List) {
      addFrom(data, null);
    } else if (data is Map) {
      final wrapped = data['items'] ?? data['stages'] ?? data['data'];
      if (wrapped is List) {
        addFrom(wrapped, null);
      } else {
        // Grouped by pipeline name → key is the section, value is the stage list.
        data.forEach((key, value) {
          if (value is List) addFrom(value, key.toString());
        });
      }
    }

    out.sort((a, b) => a.order.compareTo(b.order));
    return out;
  }

  /// Create a new lead stage.
  Future<LeadStage> createStage({
    required String name,
    required int order,
    String? section,
  }) async {
    try {
      final response = await _client.dio.post(
        ApiConstants.leadStageCreate,
        data: {
          'stage': name,
          'order': order,
          if (section != null && section.isNotEmpty) 'section': section,
        },
      );
      final data = response.data;
      if (data is Map<String, dynamic>) return LeadStage.fromJson(data);
      return LeadStage(stage: name, order: order, section: section);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Delete a lead stage by its numeric ID from the GET response.
  Future<void> deleteStage(String id) async {
    try {
      await _client.dio.delete(ApiConstants.leadStageDelete(id));
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Rename a lead stage. Migrates all leads from the old name to the new one.
  Future<void> renameStage({
    required String fromStage,
    required String toStage,
    String? section,
  }) async {
    try {
      await _client.dio.put(
        ApiConstants.leadStageRename,
        data: {
          'from_stage': fromStage,
          'to_stage': toStage,
          'section': ?section,
        },
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Reorder all lead stages by sending the full ordered list of stage names.
  Future<void> moveStages(List<String> orderedStageNames) async {
    try {
      await _client.dio.put(
        ApiConstants.leadStageMove,
        data: {'stages': orderedStageNames},
      );
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

  /// Appends [newOption] to a `select`-type custom field's option list,
  /// org-wide — every user sees it in that field's dropdown from then on.
  ///
  /// PUT /v1/lead/settings replaces the ENTIRE org field config in one call,
  /// and its documented schema (key, label, type, field_type, is_enabled,
  /// is_required) doesn't even list `options` — it's present in real
  /// responses but outside what our typed [LeadFieldSettings] model keeps
  /// (which also drops disabled/non-custom fields it doesn't render). So
  /// this works on the RAW json fields array end-to-end instead of
  /// round-tripping through that model, to guarantee every other field's
  /// config — including ones our model doesn't know about — survives
  /// untouched.
  Future<LeadFieldSettings> addCustomFieldOption({
    required String fieldKey,
    required String newOption,
  }) async {
    try {
      final getResponse = await _client.dio.get(ApiConstants.leadSettings);
      final rawFields = (getResponse.data['fields'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      final idx = rawFields.indexWhere((f) => f['key'] == fieldKey);
      if (idx == -1) throw 'Field not found';

      final options = List<String>.from(
        (rawFields[idx]['options'] as List?)?.map((e) => e.toString()) ?? [],
      );
      if (!options.contains(newOption)) {
        options.add(newOption);
        rawFields[idx] = {...rawFields[idx], 'options': options};
      }

      final putResponse = await _client.dio.put(
        ApiConstants.leadSettings,
        data: {'fields': rawFields},
      );
      return LeadFieldSettings.fromJson(putResponse.data);
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
      final detail = _detailOf(e.response?.data);
      if (detail is String) return detail;
      if (detail is List && detail.isNotEmpty) {
        final first = detail.first;
        if (first is Map && first['msg'] != null) return first['msg'].toString();
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
    final detail = _detailOf(e.response?.data);
    return detail?.toString() ?? 'Something went wrong';
  }

  /// Safely reads `detail` from a response that may be a Map, a JSON string, or
  /// raw bytes (e.g. when responseType is bytes for a file download that errored).
  dynamic _detailOf(dynamic data) {
    try {
      if (data is Map) return data['detail'];
      if (data is String) {
        final decoded = jsonDecode(data);
        if (decoded is Map) return decoded['detail'];
      }
      if (data is List<int>) {
        final decoded = jsonDecode(utf8.decode(data));
        if (decoded is Map) return decoded['detail'];
      }
    } catch (_) {
      // not JSON — ignore
    }
    return null;
  }
}
