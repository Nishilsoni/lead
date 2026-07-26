// Permission domain model + the grouping logic that powers the role editor's
// permission matrix (Module × Access/Create/View/Edit/Delete).
//
// The API returns a *flat* list of permissions — each just `{ id, name }`
// (see PermissionResponseSchema), with no module/action metadata. Real names
// look like `view_dashboard`, `view_dashboard_lead_count`, `create_lead`,
// `delete_lead` — an action verb joined to a module (and optionally a feature)
// by underscores. [PermissionCatalog.fromPermissions] reverse-engineers the
// module/action/feature structure from those names so the matrix can group
// hundreds of flat permissions into a handful of real modules, matching how
// the web app's permission table is organised.

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

  /// True when this looks like the "Assigned Data Only" scoping permission,
  /// which the role editor surfaces as a dedicated checkbox rather than a
  /// matrix cell.
  bool get isAssignedOnly {
    final n = name.toLowerCase();
    return n.contains('assigned') &&
        (n.contains('only') || n.contains('data') || n.contains('self'));
  }

  /// Lowercase words extracted from [name] — splits on `_ - . : / \` and on
  /// camelCase boundaries, so `view_dashboard`, `view.dashboard` and
  /// `viewDashboard` all tokenize the same way.
  List<String> get _tokens {
    final spaced =
        name.replaceAllMapped(RegExp(r'([a-z0-9])([A-Z])'), (m) => '${m[1]}_${m[2]}');
    return spaced
        .split(RegExp(r'[^a-zA-Z0-9]+'))
        .map((t) => t.toLowerCase())
        .where((t) => t.isNotEmpty)
        .toList();
  }

  static const Map<String, PermissionAction> _actionVerbs = {
    'access': PermissionAction.access,
    'manage': PermissionAction.access,
    'create': PermissionAction.create,
    'add': PermissionAction.create,
    'new': PermissionAction.create,
    'view': PermissionAction.view,
    'read': PermissionAction.view,
    'list': PermissionAction.view,
    'get': PermissionAction.view,
    'edit': PermissionAction.edit,
    'update': PermissionAction.edit,
    'modify': PermissionAction.edit,
    'delete': PermissionAction.delete,
    'remove': PermissionAction.delete,
    'destroy': PermissionAction.delete,
  };

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

/// A permission paired with the display label the matrix should show for it —
/// resolved by [PermissionCatalog], since a permission's role (module-level
/// action vs. named sub-feature) depends on how it compares to its siblings.
@immutable
class ModulePermission {
  final Permission permission;
  final String label;

  const ModulePermission(this.permission, this.label);

  int get id => permission.id;
  String get name => permission.name;
}

/// One row of the permission matrix: a module with up to five action cells and
/// any number of feature toggles beneath it.
class PermissionModule {
  final String key;
  final String label;

  /// Action → the permission that grants it (only the actions that exist).
  final Map<PermissionAction, ModulePermission> actions;

  /// Feature permissions (named sub-capabilities) shown as individual toggle
  /// rows, e.g. Dashboard's "Lead Count" / "Open Count" widgets.
  final List<ModulePermission> features;

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

/// Intermediate per-permission parse result, used only while building the
/// catalog. Mutable so the merge pass (see [PermissionCatalog.fromPermissions])
/// can fold a reused leaf back into the module name.
class _Parsed {
  final Permission permission;
  final PermissionAction? action;
  List<String> moduleTokens;
  List<String> leafTokens;

  _Parsed({
    required this.permission,
    required this.action,
    required this.moduleTokens,
    required this.leafTokens,
  });

  factory _Parsed.from(Permission p) {
    final tokens = p._tokens;
    if (tokens.isEmpty) {
      return _Parsed(
        permission: p,
        action: null,
        moduleTokens: [p.name],
        leafTokens: const [],
      );
    }

    PermissionAction? action;
    List<String> rest;
    if (Permission._actionVerbs.containsKey(tokens.first)) {
      action = Permission._actionVerbs[tokens.first];
      rest = tokens.sublist(1);
    } else if (tokens.length > 1 &&
        Permission._actionVerbs.containsKey(tokens.last)) {
      action = Permission._actionVerbs[tokens.last];
      rest = tokens.sublist(0, tokens.length - 1);
    } else {
      action = null;
      rest = tokens;
    }
    if (rest.isEmpty) rest = tokens;

    return _Parsed(
      permission: p,
      action: action,
      moduleTokens: [rest.first],
      leafTokens: rest.length > 1 ? rest.sublist(1) : const [],
    );
  }

  String get moduleKey => moduleTokens.join('_');
  String get leaf => leafTokens.join('_');

  /// Absorbs the leaf back into the module name — used when the same leaf
  /// text turns out to be shared by more than one action (a sign it's really
  /// part of a multi-word module name, e.g. `create_ad_account` /
  /// `view_ad_account`, rather than a distinct sub-feature).
  void mergeLeafIntoModule() {
    moduleTokens = [...moduleTokens, ...leafTokens];
    leafTokens = const [];
  }
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
    final parsed = <_Parsed>[];
    for (final p in permissions) {
      if (p.isAssignedOnly) {
        assignedOnly = p;
        continue;
      }
      parsed.add(_Parsed.from(p));
    }

    // Merge pass: within the same first-token module, if a leaf reappears
    // under more than one action, it's really part of the module's name
    // (`create/view/edit/delete_ad_account`) rather than a distinct
    // sub-feature (Dashboard's `lead_count` only ever pairs with `view`).
    final byRawModule = <String, List<_Parsed>>{};
    for (final e in parsed) {
      byRawModule.putIfAbsent(e.moduleKey, () => []).add(e);
    }
    for (final group in byRawModule.values) {
      final actionsPerLeaf = <String, Set<PermissionAction?>>{};
      for (final e in group) {
        if (e.leaf.isEmpty) continue;
        actionsPerLeaf.putIfAbsent(e.leaf, () => {}).add(e.action);
      }
      for (final e in group) {
        if (e.leaf.isEmpty) continue;
        if ((actionsPerLeaf[e.leaf] ?? const {}).length > 1) {
          e.mergeLeafIntoModule();
        }
      }
    }

    final order = <String>[];
    final byModule = <String, PermissionModule>{};
    for (final e in parsed) {
      final key = e.moduleKey;
      if (!byModule.containsKey(key)) {
        order.add(key);
        byModule[key] = PermissionModule(
          key: key,
          label: Permission.humanize(e.moduleTokens.join(' ')),
          actions: {},
          features: [],
        );
      }
      final module = byModule[key]!;
      if (e.leaf.isEmpty && e.action != null && !module.actions.containsKey(e.action)) {
        module.actions[e.action!] = ModulePermission(e.permission, e.action!.label);
      } else {
        final label = Permission.humanize(
          e.leafTokens.isEmpty ? e.moduleTokens.join(' ') : e.leafTokens.join(' '),
        );
        module.features.add(ModulePermission(e.permission, label));
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
  Set<int> get moduleIds => modules.expand((m) => m.allIds).toSet();

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
