import 'package:flutter/material.dart';
import '../models/permission.dart';
import '../models/role.dart';
import '../services/permission_service.dart';
import '../services/role_service.dart';

/// Single source of truth for roles, the permission catalog and the logged-in
/// user's own role (used to gate the administration area).
class RoleProvider extends ChangeNotifier {
  final RoleService _roleService = RoleService();
  final PermissionService _permissionService = PermissionService();

  List<Role> _roles = [];
  PermissionCatalog _catalog =
      const PermissionCatalog(modules: [], assignedOnly: null, all: []);
  CurrentRole? _currentRole;

  bool _isLoading = false;
  bool _loadedOnce = false;
  bool _isSaving = false;
  String? _error;

  List<Role> get roles => _roles;
  PermissionCatalog get catalog => _catalog;
  CurrentRole? get currentRole => _currentRole;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  bool get loadedOnce => _loadedOnce;
  String? get error => _error;

  /// Whether the current user may open the administration area. Defaults to
  /// true until we know otherwise so we never wrongly hide it — the API still
  /// enforces access server-side.
  bool get canAdminister => _currentRole?.canAdminister ?? true;

  /// Load roles + permission catalog together. No-op once loaded unless
  /// [refresh] is true.
  Future<void> load({bool refresh = false}) async {
    if (_isLoading) return;
    if (_loadedOnce && !refresh) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _roleService.getRoles(),
        _permissionService.getPermissions(),
      ]);
      _roles = results[0] as List<Role>;
      _catalog =
          PermissionCatalog.fromPermissions(results[1] as List<Permission>);
      _loadedOnce = true;
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Refresh just the current user's role for gating — cheap, safe to call on
  /// app entry to the settings area.
  Future<void> refreshCurrentRole() async {
    final role = await _roleService.getCurrentRole();
    if (role != null) {
      _currentRole = role;
      notifyListeners();
    }
  }

  Future<Role> createRole({
    required String name,
    required String description,
    required List<int> permissionIds,
  }) async {
    _isSaving = true;
    notifyListeners();
    try {
      final created = await _roleService.createRole(
        name: name,
        description: description,
        permissionIds: permissionIds,
      );
      await _reloadRoles();
      return created;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<Role> updateRole({
    required String id,
    required String description,
    required List<int> permissionIds,
  }) async {
    _isSaving = true;
    notifyListeners();
    try {
      final updated = await _roleService.updateRole(
        id: id,
        description: description,
        permissionIds: permissionIds,
      );
      await _reloadRoles();
      return updated;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<void> deleteRole(String id) async {
    _isSaving = true;
    notifyListeners();
    try {
      await _roleService.deleteRole(id);
      _roles = _roles.where((r) => r.id != id).toList();
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Roles offered when assigning a user — excludes nothing, but the caller
  /// typically shows all of them.
  List<Role> get assignableRoles => _roles;

  Future<void> _reloadRoles() async {
    try {
      _roles = await _roleService.getRoles();
    } catch (_) {
      // keep the stale list rather than clearing it
    }
  }

  void clearCache() {
    _roles = [];
    _catalog =
        const PermissionCatalog(modules: [], assignedOnly: null, all: []);
    _currentRole = null;
    _loadedOnce = false;
    _error = null;
    notifyListeners();
  }
}
