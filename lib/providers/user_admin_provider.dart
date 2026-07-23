import 'package:flutter/material.dart';
import '../models/admin_user.dart';
import '../services/user_admin_service.dart';

/// Manages the organization's user list and CRUD state for the Users
/// administration screen.
class UserAdminProvider extends ChangeNotifier {
  final UserAdminService _service = UserAdminService();

  List<AdminUser> _users = [];
  bool _isLoading = false;
  bool _loadedOnce = false;
  bool _isSaving = false;
  String? _error;

  List<AdminUser> get users => _users;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  bool get loadedOnce => _loadedOnce;
  String? get error => _error;
  int get count => _users.length;

  List<AdminUser> filtered(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return _users;
    return _users
        .where((u) =>
            u.name.toLowerCase().contains(q) ||
            u.email.toLowerCase().contains(q) ||
            (u.mobile?.toLowerCase().contains(q) ?? false) ||
            u.roleName.toLowerCase().contains(q))
        .toList();
  }

  Future<void> load({bool refresh = false}) async {
    if (_isLoading) return;
    if (_loadedOnce && !refresh) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _users = await _service.getUsers();
      _loadedOnce = true;
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> emailExists(String email) => _service.emailExists(email);

  Future<void> createUser({
    required String name,
    required String email,
    required String? mobile,
    required String password,
    required String roleId,
  }) async {
    _isSaving = true;
    notifyListeners();
    try {
      await _service.createUser(
        name: name,
        email: email,
        mobile: mobile,
        password: password,
        roleId: roleId,
      );
      await _reload();
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<void> updateUserRole({
    required String userId,
    required String roleId,
  }) async {
    _isSaving = true;
    notifyListeners();
    try {
      await _service.updateUserRole(userId: userId, roleId: roleId);
      await _reload();
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<void> deleteUser(String userId) async {
    _isSaving = true;
    notifyListeners();
    try {
      await _service.deleteUser(userId);
      _users = _users.where((u) => u.id != userId).toList();
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<void> _reload() async {
    try {
      _users = await _service.getUsers();
    } catch (_) {
      // keep the current list on a refresh failure
    }
  }

  void clearCache() {
    _users = [];
    _loadedOnce = false;
    _error = null;
    notifyListeners();
  }
}
