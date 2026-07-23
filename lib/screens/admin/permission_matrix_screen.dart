import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_theme.dart';
import '../../models/permission.dart';

/// Full-screen permission picker used by the role editor. Takes the permission
/// [catalog] and the currently-[selected] module permission ids, and returns
/// the updated set when the user confirms (or null on cancel).
///
/// The web renders a wide Module × Action table; on mobile we present the same
/// information as a stack of module cards, each with tappable action/feature
/// chips — faster to scan and tap on a phone while keeping identical semantics.
class PermissionMatrixScreen extends StatefulWidget {
  final PermissionCatalog catalog;
  final Set<int> selected;

  const PermissionMatrixScreen({
    super.key,
    required this.catalog,
    required this.selected,
  });

  static Future<Set<int>?> show(
    BuildContext context, {
    required PermissionCatalog catalog,
    required Set<int> selected,
  }) {
    return Navigator.of(context).push<Set<int>>(
      MaterialPageRoute(
        builder: (_) =>
            PermissionMatrixScreen(catalog: catalog, selected: selected),
      ),
    );
  }

  @override
  State<PermissionMatrixScreen> createState() => _PermissionMatrixScreenState();
}

class _PermissionMatrixScreenState extends State<PermissionMatrixScreen> {
  late Set<int> _selected;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _selected = {...widget.selected};
  }

  void _toggle(int id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  void _toggleModule(PermissionModule module) {
    final ids = module.allIds.toSet();
    final allOn = ids.every(_selected.contains);
    setState(() {
      if (allOn) {
        _selected.removeAll(ids);
      } else {
        _selected.addAll(ids);
      }
    });
  }

  void _applyPreset(PermissionPreset preset) {
    setState(() {
      _selected = preset == PermissionPreset.full
          ? {...widget.catalog.moduleIds}
          : widget.catalog.presetIds(preset);
    });
  }

  List<PermissionModule> get _visibleModules {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.catalog.modules;
    return widget.catalog.modules.where((m) {
      if (m.label.toLowerCase().contains(q)) return true;
      return m.features.any((f) => f.featureLabel.toLowerCase().contains(q)) ||
          m.actions.values.any((p) => p.name.toLowerCase().contains(q));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final modules = _visibleModules;
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: Text(
          'Select Permissions',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => setState(() => _selected.clear()),
            child: Text(
              'Clear',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey.shade200, height: 1),
        ),
      ),
      body: Column(
        children: [
          _buildPresets(),
          _buildSearch(),
          Expanded(
            child: modules.isEmpty
                ? Center(
                    child: Text(
                      'No modules match “$_query”.',
                      style: GoogleFonts.inter(color: AppTheme.textSecondary),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    itemCount: modules.length,
                    itemBuilder: (context, i) => _buildModuleCard(modules[i]),
                  ),
          ),
        ],
      ),
      bottomSheet: _buildConfirmBar(),
    );
  }

  Widget _buildPresets() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded,
                  size: 16, color: Color(0xFFF59E0B)),
              const SizedBox(width: 6),
              Text(
                'Quick presets',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _presetChip('No Access', Icons.block_rounded,
                  const Color(0xFF6B7280), PermissionPreset.none),
              _presetChip('Read Only', Icons.visibility_outlined,
                  AppTheme.primaryBlue, PermissionPreset.readOnly),
              _presetChip('Standard', Icons.person_outline_rounded,
                  const Color(0xFF8B5CF6), PermissionPreset.standard),
              _presetChip('Full Access', Icons.verified_user_outlined,
                  const Color(0xFF10B981), PermissionPreset.full),
            ],
          ),
        ],
      ),
    );
  }

  Widget _presetChip(
      String label, IconData icon, Color color, PermissionPreset preset) {
    return InkWell(
      onTap: () => _applyPreset(preset),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearch() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: TextField(
        onChanged: (v) => setState(() => _query = v),
        decoration: InputDecoration(
          hintText: 'Search modules or permissions',
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildModuleCard(PermissionModule module) {
    final ids = module.allIds.toList();
    final selectedCount = ids.where(_selected.contains).length;
    final allOn = ids.isNotEmpty && selectedCount == ids.length;

    // Actions rendered in fixed order so the row reads Access → Delete.
    final orderedActions = PermissionAction.values
        .where(module.actions.containsKey)
        .toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selectedCount > 0
              ? AppTheme.primaryBlue.withValues(alpha: 0.35)
              : const Color(0xFFE9ECF1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => _toggleModule(module),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(_moduleIcon(module.key),
                        size: 18, color: AppTheme.primaryBlue),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          module.label,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          '$selectedCount of ${ids.length} enabled',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => _toggleModule(module),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      allOn ? 'Clear all' : 'Select all',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade100),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (orderedActions.isNotEmpty) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: orderedActions
                        .map((a) => _permChip(
                              module.actions[a]!.id,
                              a.label,
                              icon: _actionIcon(a),
                            ))
                        .toList(),
                  ),
                ],
                if (module.features.isNotEmpty) ...[
                  if (orderedActions.isNotEmpty) const SizedBox(height: 12),
                  Text(
                    'FEATURES',
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textTertiary,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: module.features
                        .map((f) => _permChip(f.id, f.featureLabel))
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _permChip(int id, String label, {IconData? icon}) {
    final on = _selected.contains(id);
    return InkWell(
      onTap: () => _toggle(id),
      borderRadius: BorderRadius.circular(9),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: on ? AppTheme.primaryBlue : AppTheme.surfaceGrey,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: on ? AppTheme.primaryBlue : const Color(0xFFE5E7EB),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              on ? Icons.check_rounded : (icon ?? Icons.circle_outlined),
              size: 15,
              color: on ? Colors.white : AppTheme.textTertiary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: on ? Colors.white : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_selected.length} selected',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  'across ${widget.catalog.moduleCount} modules',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, _selected),
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('Confirm Selection'),
          ),
        ],
      ),
    );
  }

  IconData _actionIcon(PermissionAction a) {
    switch (a) {
      case PermissionAction.access:
        return Icons.login_rounded;
      case PermissionAction.create:
        return Icons.add_rounded;
      case PermissionAction.view:
        return Icons.visibility_outlined;
      case PermissionAction.edit:
        return Icons.edit_outlined;
      case PermissionAction.delete:
        return Icons.delete_outline_rounded;
    }
  }

  IconData _moduleIcon(String key) {
    final k = key.toLowerCase();
    if (k.contains('dashboard')) return Icons.dashboard_outlined;
    if (k.contains('lead')) return Icons.person_pin_circle_outlined;
    if (k.contains('contact')) return Icons.contacts_outlined;
    if (k.contains('appointment') || k.contains('calendar')) {
      return Icons.event_outlined;
    }
    if (k.contains('tag')) return Icons.label_outline_rounded;
    if (k.contains('product')) return Icons.inventory_2_outlined;
    if (k.contains('report') || k.contains('analytic')) {
      return Icons.bar_chart_rounded;
    }
    if (k.contains('user')) return Icons.group_outlined;
    if (k.contains('role') || k.contains('permission')) {
      return Icons.shield_outlined;
    }
    if (k.contains('billing') || k.contains('plan') || k.contains('invoice')) {
      return Icons.receipt_long_outlined;
    }
    if (k.contains('setting')) return Icons.settings_outlined;
    if (k.contains('market') || k.contains('campaign') || k.contains('meta')) {
      return Icons.campaign_outlined;
    }
    if (k.contains('interaction') || k.contains('activity')) {
      return Icons.forum_outlined;
    }
    return Icons.widgets_outlined;
  }
}
