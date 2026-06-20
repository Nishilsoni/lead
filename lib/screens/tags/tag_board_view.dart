import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/config/environment_service.dart';
import '../../core/constants/app_theme.dart';
import '../../models/lead.dart';
import '../../providers/lead_provider.dart';
import '../../providers/tag_provider.dart';
import '../../utils/shared_prefs.dart';

/// Action requested from a tag column's 3-dot menu.
enum TagColumnAction { rename, clear, delete }

/// Drag feedback for reorderable tag columns: a subtle "lift" — the held column
/// scales up and gains a shadow so you can feel you're holding it.
Widget _dragProxy(Widget child, int index, Animation<double> animation) {
  return AnimatedBuilder(
    animation: animation,
    builder: (context, _) {
      final t = Curves.easeInOut.transform(animation.value);
      return Transform.scale(
        scale: 1.0 + 0.05 * t,
        child: Material(
          color: Colors.transparent,
          elevation: 12 * t,
          shadowColor: Colors.black.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(16),
          child: child,
        ),
      );
    },
  );
}

/// Kanban board of leads grouped by TAG — one column per tag, each with a lead
/// count + total potential value and modern cards. A lead carrying multiple tags
/// appears in each matching column.
///
/// Columns can be drag-reordered (the order persists per org), each header has a
/// "+" to create a lead pre-tagged with that tag, and a 3-dot menu to rename the
/// tag, clear all its leads, or delete it. Tap a card to open the lead.
class TagBoardView extends StatefulWidget {
  /// Tap a card → open the lead.
  final void Function(Lead) onTapLead;

  /// "+" on a column → create a lead with this tag pre-selected.
  final void Function(String tagName) onAddLead;

  /// 3-dot menu action on a column.
  final void Function(String tagName, TagColumnAction action) onColumnAction;

  const TagBoardView({
    super.key,
    required this.onTapLead,
    required this.onAddLead,
    required this.onColumnAction,
  });

  @override
  State<TagBoardView> createState() => _TagBoardViewState();
}

class _TagBoardViewState extends State<TagBoardView> {
  /// User-chosen column order (tag names). Empty = default usage order.
  List<String> _manualOrder = [];

  String get _orderKey =>
      'tag_board_order_${EnvironmentService.instance.activeOrgId ?? 'default'}';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LeadProvider>().loadBoardLeads();
      context.read<TagProvider>().loadTags();
    });
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    await SharedPrefs.getInstance();
    final saved = SharedPrefs.getStringList(_orderKey);
    if (saved != null && mounted) {
      setState(() => _manualOrder = saved);
    }
  }

  Future<void> _refresh() async {
    await Future.wait([
      context.read<LeadProvider>().loadBoardLeads(refresh: true),
      context.read<TagProvider>().loadTags(refresh: true),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<TagProvider, LeadProvider>(
      builder: (context, tagProvider, leadProvider, _) {
        if (leadProvider.boardLoading && leadProvider.boardLeads.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (leadProvider.boardError != null &&
            leadProvider.boardLeads.isEmpty) {
          return _error(leadProvider);
        }

        final columns = _buildColumns(tagProvider, leadProvider.boardLeads);

        if (columns.isEmpty) {
          return RefreshIndicator(
            onRefresh: _refresh,
            color: AppTheme.primaryBlue,
            child: ListView(
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.view_kanban_outlined,
                        size: 44,
                        color: AppTheme.textTertiary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No tags to show',
                        style: GoogleFonts.inter(
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        // Inner column lists are vertical, so their overscroll bubbles up to
        // power pull-to-refresh even though the board itself scrolls sideways.
        return RefreshIndicator(
          onRefresh: _refresh,
          color: AppTheme.primaryBlue,
          child: ReorderableListView.builder(
            scrollDirection: Axis.horizontal,
            buildDefaultDragHandles: false,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            itemCount: columns.length,
            proxyDecorator: _dragProxy,
            onReorderItem: (oldIndex, newIndex) =>
                _onReorder(columns, oldIndex, newIndex),
            itemBuilder: (context, i) => _buildColumn(
              columns[i],
              reorderIndex: i,
              key: ValueKey('tagcol_${columns[i].name}'),
            ),
          ),
        );
      },
    );
  }

  Widget _error(LeadProvider provider) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 44,
            color: Colors.red.shade300,
          ),
          const SizedBox(height: 12),
          Text(
            provider.boardError!,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => provider.loadBoardLeads(refresh: true),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  // ── Reorder ───────────────────────────────────────────────────────────────

  void _onReorder(List<_TagColumn> columns, int oldIndex, int newIndex) {
    // onReorderItem already adjusts newIndex for the removed item.
    final names = columns.map((c) => c.name).toList();
    final moved = names.removeAt(oldIndex);
    names.insert(newIndex, moved);
    setState(() => _manualOrder = names);
    SharedPrefs.setStringList(_orderKey, names);
  }

  // ── Columns ───────────────────────────────────────────────────────────────

  List<_TagColumn> _buildColumns(TagProvider tagProvider, List<Lead> leads) {
    // Count how many leads carry each tag name.
    final counts = <String, int>{};
    for (final lead in leads) {
      for (final t in lead.tags) {
        counts[t] = (counts[t] ?? 0) + 1;
      }
    }

    // Union of org tags (so empty tags still appear) + any free-text tags on
    // leads, ordered by usage (most-used first), then alphabetically.
    final names = <String>{...tagProvider.tagNames, ...counts.keys}.toList()
      ..sort((a, b) {
        final byCount = (counts[b] ?? 0).compareTo(counts[a] ?? 0);
        return byCount != 0
            ? byCount
            : a.toLowerCase().compareTo(b.toLowerCase());
      });

    // Apply the manual (drag) order on top: names present in _manualOrder lead,
    // in that order; everything else keeps the usage order at the end.
    if (_manualOrder.isNotEmpty) {
      final rank = {
        for (var i = 0; i < _manualOrder.length; i++) _manualOrder[i]: i,
      };
      names.sort((a, b) {
        final ra = rank[a] ?? (1 << 30);
        final rb = rank[b] ?? (1 << 30);
        return ra != rb ? ra.compareTo(rb) : 0;
      });
    }

    return names
        .map(
          (name) => _TagColumn(
            name: name,
            leads: leads.where((l) => l.tags.contains(name)).toList(),
            color: AppTheme.stageColor(name),
          ),
        )
        .toList();
  }

  Widget _buildColumn(_TagColumn col, {required int reorderIndex, Key? key}) {
    final total = col.leads.fold<int>(0, (sum, l) => sum + l.potential);
    final darkColor = _darken(col.color);

    return Container(
      key: key,
      width: 290,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F4F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: col.color.withValues(alpha: 0.30),
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Colored top accent strip
            Container(height: 5, color: col.color),

            // Header with subtle tag-color tint
            Container(
              padding: const EdgeInsets.fromLTRB(12, 9, 6, 9),
              decoration: BoxDecoration(
                color: col.color.withValues(alpha: 0.10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.sell_rounded, size: 14, color: darkColor),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          col.name.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                            color: darkColor,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: col.color.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${col.leads.length}',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: darkColor,
                          ),
                        ),
                      ),
                      // Add lead with this tag
                      _headerIcon(
                        icon: Icons.add_rounded,
                        color: darkColor,
                        tooltip: 'New lead with this tag',
                        onTap: () => widget.onAddLead(col.name),
                      ),
                      // 3-dot menu
                      PopupMenuButton<TagColumnAction>(
                        tooltip: 'Tag options',
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        icon: Icon(
                          Icons.more_vert_rounded,
                          size: 18,
                          color: darkColor,
                        ),
                        onSelected: (a) => widget.onColumnAction(col.name, a),
                        itemBuilder: (_) => [
                          _menuItem(
                            TagColumnAction.rename,
                            Icons.edit_outlined,
                            'Edit tag name',
                          ),
                          _menuItem(
                            TagColumnAction.clear,
                            Icons.layers_clear_rounded,
                            'Clear all cards',
                          ),
                          _menuItem(
                            TagColumnAction.delete,
                            Icons.delete_outline_rounded,
                            'Delete tag',
                            destructive: true,
                          ),
                        ],
                      ),
                      // Drag handle
                      ReorderableDragStartListener(
                        index: reorderIndex,
                        child: Icon(
                          Icons.drag_indicator_rounded,
                          size: 18,
                          color: darkColor.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Padding(
                    padding: const EdgeInsets.only(left: 2),
                    child: Text(
                      _formatCurrency(total),
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: darkColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Cards
            Expanded(
              child: col.leads.isEmpty
                  ? _emptyColumn()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                      itemCount: col.leads.length,
                      itemBuilder: (context, i) => _TagBoardCard(
                        lead: col.leads[i],
                        onTap: () => widget.onTapLead(col.leads[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerIcon({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(7),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }

  PopupMenuItem<TagColumnAction> _menuItem(
    TagColumnAction value,
    IconData icon,
    String label, {
    bool destructive = false,
  }) {
    final color = destructive ? const Color(0xFFEF4444) : AppTheme.textPrimary;
    return PopupMenuItem<TagColumnAction>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 12),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyColumn() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          'No leads',
          style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textTertiary),
        ),
      ),
    );
  }

  String _formatCurrency(int value) {
    // Indian-style grouping with ₹ prefix and .00 to match the web.
    final s = value.toString();
    final buf = StringBuffer();
    final digits = s.length;
    for (var i = 0; i < digits; i++) {
      buf.write(s[i]);
      final remaining = digits - i - 1;
      if (remaining > 3 && (remaining - 3) % 2 == 0) buf.write(',');
      if (remaining == 3) buf.write(',');
    }
    return '₹$buf.00';
  }
}

/// Darken a color (for text/icons over a light tint of the same hue).
Color _darken(Color c) {
  final hsl = HSLColor.fromColor(c);
  return hsl.withLightness((hsl.lightness - 0.18).clamp(0.0, 1.0)).toColor();
}

class _TagColumn {
  final String name;
  final List<Lead> leads;
  final Color color;
  _TagColumn({required this.name, required this.leads, required this.color});
}

// ── Board Card ────────────────────────────────────────────────────────────────

class _TagBoardCard extends StatelessWidget {
  final Lead lead;
  final VoidCallback onTap;

  const _TagBoardCard({required this.lead, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE9EDF3), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lead.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (lead.business.name.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    lead.business.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],

                // Stage badge
                if (lead.stage.isNotEmpty) ...[
                  const SizedBox(height: 9),
                  _stageBadge(lead.stage),
                ],

                // Tag chips
                if (lead.tags.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: lead.tags.map(_tagChip).toList(),
                  ),
                ],

                const SizedBox(height: 10),
                Row(
                  children: [
                    if (lead.potential > 0) ...[
                      Icon(
                        Icons.currency_rupee_rounded,
                        size: 13,
                        color: AppTheme.textTertiary,
                      ),
                      Text(
                        _short(lead.potential),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 12,
                      color: AppTheme.textTertiary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _shortDate(lead.since),
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        color: AppTheme.textTertiary,
                      ),
                    ),
                    const Spacer(),
                    if (lead.assignedUser != null)
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _initials(lead.assignedUser!.name),
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stageBadge(String stage) {
    final color = AppTheme.stageColor(stage);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        stage.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: _darken(color),
        ),
      ),
    );
  }

  Widget _tagChip(String tag) {
    final color = AppTheme.stageColor(tag);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        tag,
        style: GoogleFonts.inter(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: _darken(color),
        ),
      ),
    );
  }

  String _short(int v) {
    if (v >= 10000000) return '${(v / 10000000).toStringAsFixed(1)}Cr';
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return '$v';
  }

  String _shortDate(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}';
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}
