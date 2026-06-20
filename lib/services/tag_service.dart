import 'dart:convert';
import 'package:dio/dio.dart';
import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../models/paginated_response.dart';
import '../models/tag.dart';

/// Service layer for tag CRUD operations.
///
/// The org is injected automatically as the `x-org-id` header by [ApiClient]'s
/// interceptor, and the base URL is environment-driven — so the same code works
/// against both test and prod without any changes here.
class TagService {
  final ApiClient _client = ApiClient();

  // ── Read ─────────────────────────────────────────────────────────

  /// Fetch a single page of tags, optionally filtered by [query].
  Future<PaginatedResponse<Tag>> getTags({
    int page = 1,
    int pageSize = 100,
    String? query,
  }) async {
    try {
      final response = await _client.dio.get(
        ApiConstants.tags,
        queryParameters: {
          'page': page,
          'page_size': pageSize,
          if (query != null && query.isNotEmpty) 'q': query,
        },
      );
      return PaginatedResponse<Tag>.fromJson(
        response.data,
        (json) => Tag.fromJson(json),
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Fetch every tag across all pages (used for selectors and the manager).
  Future<List<Tag>> getAllTags() async {
    const pageSize = 200;
    final all = <Tag>[];
    var page = 1;
    while (true) {
      final result = await getTags(page: page, pageSize: pageSize);
      all.addAll(result.items);
      if (!result.hasMore || page >= 50) break;
      page++;
    }
    return all;
  }

  // ── Write ────────────────────────────────────────────────────────

  /// Create a new tag.
  Future<Tag> createTag(String name) async {
    try {
      final response = await _client.dio.post(
        ApiConstants.tags,
        data: {'name': name},
      );
      return Tag.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Rename an existing tag.
  Future<Tag> updateTag(int id, String name) async {
    try {
      final response = await _client.dio.put(
        ApiConstants.tagById(id),
        data: {'name': name},
      );
      return Tag.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Delete a tag by id.
  Future<void> deleteTag(int id) async {
    try {
      await _client.dio.delete(ApiConstants.tagById(id));
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
      return 'Tag not found.';
    }
    if (e.response?.statusCode == 409) {
      return 'A tag with that name already exists.';
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

  dynamic _detailOf(dynamic data) {
    try {
      if (data is Map) return data['detail'];
      if (data is String) {
        final decoded = jsonDecode(data);
        if (decoded is Map) return decoded['detail'];
      }
    } catch (_) {
      // not JSON — ignore
    }
    return null;
  }
}
