// Role domain models matching the OceanCRM API.
//
// A [Role] (RoleSchema) bundles a set of permissions under a named,
// describable unit. `is_default` marks the three built-in roles
// (ADMIN / AGENCY / USER) which can't be deleted or renamed.
//
// [CurrentRole] (RoleResponseSchema) is the lighter shape returned by
// GET /v1/role/current for the logged-in user — its `permissions` are plain
// name strings, which we use to gate what the current user is allowed to do.

import 'package:flutter/foundation.dart';
import 'permission.dart';

@immutable
class Role {
  final String id;
  final String name;
  final String description;
  final List<Permission> permissions;
  final bool isDefault;

  const Role({
    required this.id,
    required this.name,
    required this.description,
    required this.permissions,
    required this.isDefault,
  });

  factory Role.fromJson(Map<String, dynamic> json) {
    final rawPerms = json['permissions'];
    final perms = <Permission>[];
    if (rawPerms is List) {
      for (final p in rawPerms) {
        if (p is Map<String, dynamic>) {
          perms.add(Permission.fromJson(p));
        } else if (p is Map) {
          perms.add(Permission.fromJson(Map<String, dynamic>.from(p)));
        }
      }
    }
    return Role(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      permissions: perms,
      isDefault: json['is_default'] == true,
    );
  }

  /// Ids of the permissions this role grants — the initial selection when
  /// editing the role.
  Set<int> get permissionIds => permissions.map((p) => p.id).toSet();

  int get permissionCount => permissions.length;

  /// True when this role carries the "Assigned Data Only" scoping permission.
  bool get isAssignedOnly => permissions.any((p) => p.isAssignedOnly);

  Role copyWith({
    String? name,
    String? description,
    List<Permission>? permissions,
  }) =>
      Role(
        id: id,
        name: name ?? this.name,
        description: description ?? this.description,
        permissions: permissions ?? this.permissions,
        isDefault: isDefault,
      );
}

/// The logged-in user's own role, with permissions as name strings.
@immutable
class CurrentRole {
  final String id;
  final String name;
  final Set<String> permissions;

  const CurrentRole({
    required this.id,
    required this.name,
    required this.permissions,
  });

  factory CurrentRole.fromJson(Map<String, dynamic> json) {
    final raw = json['permissions'];
    final perms = <String>{};
    if (raw is List) {
      for (final p in raw) {
        perms.add(p.toString());
      }
    }
    return CurrentRole(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      permissions: perms,
    );
  }

  bool get isAdminLike {
    final n = name.toUpperCase();
    return n == 'ADMIN' || n == 'AGENCY';
  }

  /// Whether this role can reach the administration area at all. Admin/agency
  /// always can; otherwise we look for any user- or role-management permission.
  bool get canAdminister {
    if (isAdminLike) return true;
    return permissions.any((p) {
      final l = p.toLowerCase();
      return l.contains('user') || l.contains('role');
    });
  }
}
