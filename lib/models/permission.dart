// Permission domain model + the grouping logic that powers the role editor's
// permission matrix (Module × Access/Create/View/Edit/Delete).
//
// The API returns a *flat* list of permissions — each just `{ id, name }`
// (see PermissionResponseSchema). The web app renders them as a grid grouped
// by module, so we reproduce that grouping here by parsing the permission
// name. Names are expected to encode a module and a leaf, separated by one of
// `: . /` — e.g. `dashboard:access`, `lead.create`, `dashboard/lead_count`.
//
// The parser is deliberately forgiving: anything it can't classify as one of
// the five standard actions becomes a labelled *feature* row (a single toggle),
// and a name with no separator becomes its own single-toggle module. That way
// the matrix stays correct and usable whatever naming convention the backend
// happens to use.

import 'package:flutter/foundation.dart';

/// The five standard columns shown in the permission matrix.
enum PermissionAction { access, create, view, edit, delete }

extension PermissionActionLabel on PermissionAction {
  String get label {
    switch (this) {
      case PermissionAction.access:
        return 'Access';
      case PermissionAction.create:
        return 'Create';
      case PermissionAction.view:
        return 'View';
      case PermissionAction.edit:
        return 'Edit';
      case PermissionAction.delete:
        return 'Delete';
    }
  }
}

/// A single permission as returned by the API.
@immutable
class Permission {
  final int id;
  final String name;

  const Permission({required this.id, required this.name});

  factory Permission.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    return Permission(
      id: rawId is int
          ? rawId
          : int.tryParse(rawId?.toString() ?? '') ?? 0,
      name: json['name']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  // ── Parsing helpers ─────────────────────────────────────────────

  /// The part of the name before the first `: . /` separator — the module key.
  /// If there's no separator the whole name is the module key.
  String get moduleKey {
    final parts = _segments;
    return parts.isEmpty ? name : parts.first;
  }

  /// The part after the first separator (joined if there were several),
  /// or an empty string for a separator-less name.
  String get leaf {
    final parts = _segments;
    return parts.length > 1 ? parts.sublist(1).join(' ') : '';
  }

  List<String> get _segments => name
      .split(RegExp(r'[:./\\]'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  /// Maps the leaf to one of the five standard actions, or null when the leaf
  /// isn't a recognised CRUD verb (in which case it's a feature toggle).
  PermissionAction? get action {
    final l = leaf.isEmpty ? _segments.firstOrNull ?? name : leaf;
    final k = l.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    switch (k) {
      case 'access':
      case 'manage':
        return PermissionAction.access;
      case 'create':
      case 'add':
      case 'new':
        return PermissionAction.create;
      case 'view':
      case 'read':
      case 'list':
      case 'get':
        return PermissionAction.view;
      case 'edit':
      case 'update':
      case 'modify':
        return PermissionAction.edit;
      case 'delete':
      case 'remove':
      case 'destroy':
        return PermissionAction.delete;
      default:
        return null;
    }
  }

  /// True when the leaf isn't a CRUD action — rendered as its own toggle row.
  bool get isFeature => leaf.isNotEmpty && action == null;

  /// True when this looks like the "Assigned Data Only" scoping permission,
  /// which the role editor surfaces as a dedicated checkbox rather than a
  /// matrix cell.
  bool get isAssignedOnly {
    final n = name.toLowerCase();
    return n.contains('assigned') &&
        (n.contains('only') || n.contains('data') || n.contains('self'));
  }

  /// Human-readable module title, e.g. `lead_count` → `Lead Count`.
  String get moduleLabel => humanize(moduleKey);

  /// Human-readable feature label derived from the leaf.
  String get featureLabel => humanize(leaf.isEmpty ? name : leaf);

  static String humanize(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[_\-]+'), ' ').trim();
    if (cleaned.isEmpty) return raw;
    return cleaned
        .split(RegExp(r'\s+'))
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  @override
  bool operator ==(Object other) => other is Permission && other.id == id;

  @override
  int get hashCode => id;
}

/// One row of the permission matrix: a module with up to five action cells and
/// any number of feature toggles beneath it.
class PermissionModule {
  final String key;
  final String label;

  /// Action → the permission that grants it (only the actions that exist).
  final Map<PermissionAction, Permission> actions;

  /// Feature permissions (non-CRUD leaves) shown as individual toggle rows.
  final List<Permission> features;

  PermissionModule({
    required this.key,
    required this.label,
    required this.actions,
    required this.features,
  });

  /// Every permission id in this module (actions + features).
  Iterable<int> get allIds =>
      [...actions.values.map((p) => p.id), ...features.map((p) => p.id)];
}

/// Groups a flat permission list into ordered [PermissionModule]s and exposes
/// the "assigned data only" permission separately when present.
class PermissionCatalog {
  final List<PermissionModule> modules;
  final Permission? assignedOnly;
  final List<Permission> all;

  const PermissionCatalog({
    required this.modules,
    required this.assignedOnly,
    required this.all,
  });

  factory PermissionCatalog.fromPermissions(List<Permission> permissions) {
    Permission? assignedOnly;
    final byModule = <String, PermissionModule>{};
    final order = <String>[];

    for (final p in permissions) {
      if (p.isAssignedOnly) {
        assignedOnly = p;
        continue;
      }
      final key = p.moduleKey;
      if (!byModule.containsKey(key)) {
        order.add(key);
        byModule[key] = PermissionModule(
          key: key,
          label: p.moduleLabel,
          actions: {},
          features: [],
        );
      }
      final module = byModule[key]!;
      final action = p.action;
      if (action != null && !module.actions.containsKey(action)) {
        module.actions[action] = p;
      } else {
        module.features.add(p);
      }
    }

    return PermissionCatalog(
      modules: order.map((k) => byModule[k]!).toList(),
      assignedOnly: assignedOnly,
      all: permissions,
    );
  }

  bool get isEmpty => all.isEmpty;

  /// Every permission id that lives in the matrix (i.e. excluding the special
  /// "assigned data only" permission, which the role form handles separately).
  Set<int> get moduleIds =>
      modules.expand((m) => m.allIds).toSet();

  int get moduleCount => modules.length;

  /// Ids selected by a quick preset, evaluated against this catalog.
  ///  • none      → nothing
  ///  • readOnly  → access + view actions, plus all feature toggles
  ///  • standard  → access + view + create + edit, plus all features
  ///  • full      → everything (incl. assigned-only)
  Set<int> presetIds(PermissionPreset preset) {
    switch (preset) {
      case PermissionPreset.none:
        return {};
      case PermissionPreset.full:
        return all.map((p) => p.id).toSet();
      case PermissionPreset.readOnly:
        return _idsForActions(
          {PermissionAction.access, PermissionAction.view},
          includeFeatures: true,
        );
      case PermissionPreset.standard:
        return _idsForActions(
          {
            PermissionAction.access,
            PermissionAction.view,
            PermissionAction.create,
            PermissionAction.edit,
          },
          includeFeatures: true,
        );
    }
  }

  Set<int> _idsForActions(
    Set<PermissionAction> actions, {
    required bool includeFeatures,
  }) {
    final ids = <int>{};
    for (final m in modules) {
      for (final entry in m.actions.entries) {
        if (actions.contains(entry.key)) ids.add(entry.value.id);
      }
      if (includeFeatures) {
        ids.addAll(m.features.map((p) => p.id));
      }
    }
    return ids;
  }
}

enum PermissionPreset { none, readOnly, standard, full }

extension _FirstOrNull<E> on List<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
