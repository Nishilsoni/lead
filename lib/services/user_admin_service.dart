import 'package:dio/dio.dart';
import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../models/admin_user.dart';
import 'admin_api_error.dart';

/// CRUD for organization users (the administration Users list).
///
/// Note the API only lets you change a user's *role* after creation
/// (UpdateUserSchema = { role_id }); name/email/mobile are fixed at creation.
class UserAdminService with AdminApiError {
  final ApiClient _client = ApiClient();

  // ── Read ─────────────────────────────────────────────────────────

  Future<List<AdminUser>> getUsers() async {
    try {
      final response = await _client.dio.get(ApiConstants.users);
      final data = response.data;
      final list = data is List
          ? data
          : (data is Map && data['items'] is List ? data['items'] as List : const []);
      return list
          .whereType<Map>()
          .map((m) => AdminUser.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } on DioException catch (e) {
      throw humanizeError(e, subject: 'user');
    }
  }

  /// Returns true when an account already exists for [email].
  Future<bool> emailExists(String email) async {
    try {
      final response = await _client.dio.post(
        ApiConstants.userExists,
        data: {'email': email},
      );
      final data = response.data;
      if (data is bool) return data;
      if (data is Map) {
        final v = data['exists'] ?? data['user_exists'] ?? data['result'];
        if (v is bool) return v;
      }
      return false;
    } on DioException catch (_) {
      // Non-fatal: let the create call surface the real conflict if any.
      return false;
    }
  }

  // ── Write ────────────────────────────────────────────────────────

  /// Creates a full user account. [mobile] should already include the country
  /// code (e.g. `+917898764539`).
  Future<void> createUser({
    required String name,
    required String email,
    required String? mobile,
    required String password,
    required String roleId,
  }) async {
    try {
      await _client.dio.post(
        ApiConstants.users,
        data: {
          'name': name,
          'email': email,
          if (mobile != null && mobile.isNotEmpty) 'mobile': mobile,
          'password': password,
          'role_id': roleId,
        },
      );
    } on DioException catch (e) {
      throw humanizeError(e, subject: 'user');
    }
  }

  /// Changes a user's role.
  Future<void> updateUserRole({
    required String userId,
    required String roleId,
  }) async {
    try {
      await _client.dio.put(
        ApiConstants.userById(userId),
        data: {'role_id': roleId},
      );
    } on DioException catch (e) {
      throw humanizeError(e, subject: 'user');
    }
  }

  Future<void> deleteUser(String userId) async {
    try {
      await _client.dio.delete(ApiConstants.userById(userId));
    } on DioException catch (e) {
      throw humanizeError(e, subject: 'user');
    }
  }
}
