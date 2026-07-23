import 'package:dio/dio.dart';
import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../models/role.dart';
import 'admin_api_error.dart';

/// CRUD for org roles plus the logged-in user's own role.
///
/// The `x-org-id` header and base URL are injected by [ApiClient], so the same
/// code works against test and prod unchanged.
class RoleService with AdminApiError {
  final ApiClient _client = ApiClient();

  // ── Read ─────────────────────────────────────────────────────────

  Future<List<Role>> getRoles() async {
    try {
      final response = await _client.dio.get(ApiConstants.roles);
      final data = response.data;
      final list = data is List ? data : const [];
      return list
          .whereType<Map>()
          .map((m) => Role.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } on DioException catch (e) {
      throw humanizeError(e, subject: 'role');
    }
  }

  Future<CurrentRole?> getCurrentRole() async {
    try {
      final response = await _client.dio.get(ApiConstants.currentRole);
      final data = response.data;
      if (data is Map) {
        return CurrentRole.fromJson(Map<String, dynamic>.from(data));
      }
      return null;
    } on DioException catch (_) {
      // Gating is best-effort — never block the UI if this fails.
      return null;
    }
  }

  // ── Write ────────────────────────────────────────────────────────

  Future<Role> createRole({
    required String name,
    required String description,
    required List<int> permissionIds,
  }) async {
    try {
      final response = await _client.dio.post(
        ApiConstants.roles,
        data: {
          'name': name,
          'description': description,
          'permission_ids': permissionIds,
        },
      );
      return _roleFromWrite(response, name, description);
    } on DioException catch (e) {
      throw humanizeError(e, subject: 'role');
    }
  }

  Future<Role> updateRole({
    required String id,
    required String description,
    required List<int> permissionIds,
  }) async {
    try {
      final response = await _client.dio.put(
        ApiConstants.roleById(id),
        data: {
          'description': description,
          'permission_ids': permissionIds,
        },
      );
      return _roleFromWrite(response, null, description);
    } on DioException catch (e) {
      throw humanizeError(e, subject: 'role');
    }
  }

  Future<void> deleteRole(String id) async {
    try {
      await _client.dio.delete(ApiConstants.roleById(id));
    } on DioException catch (e) {
      throw humanizeError(e, subject: 'role');
    }
  }

  /// The create/update responses vary (AddedRole / UpdatedRole wrappers), so we
  /// parse defensively and fall back to a locally-constructed role. The list is
  /// always refetched afterwards anyway, so this only needs to be good enough
  /// to return without throwing.
  Role _roleFromWrite(Response response, String? name, String description) {
    final data = response.data;
    Map<String, dynamic>? map;
    if (data is Map) {
      final inner = data['role'] ?? data['data'] ?? data;
      if (inner is Map) map = Map<String, dynamic>.from(inner);
    }
    if (map != null && map['id'] != null) {
      return Role.fromJson(map);
    }
    return Role(
      id: map?['id']?.toString() ?? '',
      name: name ?? map?['name']?.toString() ?? '',
      description: description,
      permissions: const [],
      isDefault: false,
    );
  }
}
