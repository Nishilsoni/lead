import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_theme.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../models/lead.dart';
import '../../providers/lead_provider.dart';

enum BoardGrouping { stage, assignee }

/// Drag feedback for reorderable board columns: a subtle "lift" — the held
/// column scales up and gains a shadow so you can feel you're holding it.
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

/// Kanban board view of leads — columns per stage (or per assignee), each with a
/// count + total potential value, modern cards, and drag-to-move between columns.
class LeadBoardView extends StatefulWidget {
  final BoardGrouping grouping;

  /// Client-side filter predicate applied to the board leads (from the toolbar).
  final bool Function(Lead) filter;

  /// Optional comparator for ordering cards within a column.
  final int Function(Lead, Lead)? sort;

  /// Only show stage columns whose section is in this set (empty = all).
  /// Only applies when grouping by stage.
  final Set<String> pipelines;

  final void Function(Lead) onTapLead;

  /// Create a new lead pre-set to the given stage (column "+" button).
  final void Function(String stage)? onAddLeadToStage;

  const LeadBoardView({
    super.key,
    required this.grouping,
    required this.filter,
    required this.onTapLead,
    required this.pipelines,
    this.onAddLeadToStage,
    this.sort,
  });

  @override
  State<LeadBoardView> createState() => _LeadBoardViewState();
}

class _LeadBoardViewState extends State<LeadBoardView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LeadProvider>().loadBoardLeads();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LeadProvider>(
      builder: (context, provider, _) {
        if (provider.boardLoading && provider.boardLeads.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (provider.boardError != null && provider.boardLeads.isEmpty) {
          return _error(provider);
        }

        final leads = provider.boardLeads.where(widget.filter).toList();
        final columns = _buildColumns(provider, leads);

        if (columns.isEmpty) {
          return Center(
            child: Text(
              'No leads to show',
              style: GoogleFonts.inter(color: AppTheme.textSecondary),
            ),
          );
        }

        // Stage mode supports drag-to-reorder columns; assignee mode is static.
        final canReorder = widget.grouping == BoardGrouping.stage;

        return RefreshIndicator(
          onRefresh: () => provider.loadBoardLeads(refresh: true),
          color: AppTheme.primaryBlue,
          child: canReorder
              ? ReorderableListView.builder(
                  scrollDirection: Axis.horizontal,
                  buildDefaultDragHandles: false,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  itemCount: columns.length,
                  proxyDecorator: _dragProxy,
                  onReorderItem: (oldIndex, newIndex) =>
                      _onReorderColumns(provider, columns, oldIndex, newIndex),
                  itemBuilder: (context, i) => _buildColumn(
                    provider,
                    columns[i],
                    reorderIndex: i,
                    key: ValueKey('col_${columns[i].key}'),
                  ),
                )
              : ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  children: [
                    for (final col in columns) _buildColumn(provider, col),
                  ],
                ),
        );
      },
    );
  }

  Future<void> _onReorderColumns(
    LeadProvider provider,
    List<_Column> columns,
    int oldIndex,
    int newIndex,
  ) async {
    final names = columns.map((c) => c.key).toList();
    final moved = names.removeAt(oldIndex);
    names.insert(newIndex, moved);

    // Merge the reordered (possibly filtered) subset back into the full order so
    // stages from other pipelines keep their positions.
    final full = provider.stages.map((s) => s.stage).toList();
    final visible = columns.map((c) => c.key).toSet();
    final result = <String>[];
    var vi = 0;
    for (final name in full) {
      if (visible.contains(name)) {
        // place the next visible-in-new-order name
        while (vi < names.length && !visible.contains(names[vi])) {
          vi++;
        }
        if (vi < names.length) result.add(names[vi++]);
      } else {
        result.add(name);
      }
    }
    try {
      await provider.reorderStages(result);
      if (mounted) {
        SnackbarHelper.showSuccess(context, 'Pipeline order updated');
      }
    } catch (_) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Could not reorder stages');
      }
    }
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

  // ── Column model ──────────────────────────────────────────────────────────

  List<_Column> _buildColumns(LeadProvider provider, List<Lead> leads) {
    if (widget.grouping == BoardGrouping.stage) {
      // Apply pipeline (section) filter if any pipelines are selected.
      // If the backend doesn't tag stages with a section at all, the filter
      // can't apply — show every stage rather than an empty board.
      final hasSections = provider.stages.any(
        (s) => s.section != null && s.section!.isNotEmpty,
      );
      final stages = (widget.pipelines.isEmpty || !hasSections)
          ? provider.stages
          : provider.stages
                .where(
                  (s) =>
                      s.section != null && widget.pipelines.contains(s.section),
                )
                .toList();
      final order = {
        for (var i = 0; i < stages.length; i++) stages[i].stage: i,
      };
      final allowed = stages.map((s) => s.stage).toSet();
      // Group leads by their stage; keep stages even if empty.
      final map = <String, List<Lead>>{for (final s in stages) s.stage: []};
      for (final l in leads) {
        if (allowed.contains(l.stage)) (map[l.stage] ??= []).add(l);
      }
      final cols =
          map.entries
              .map(
                (e) => _Column(
                  key: e.key,
                  title: e.key,
                  leads: _sorted(e.value),
                  color: AppTheme.stageColor(e.key),
                ),
              )
              .toList()
            ..sort(
              (a, b) => (order[a.key] ?? 999).compareTo(order[b.key] ?? 999),
            );
      return cols;
    } else {
      // Group by assignee.
      final map = <String, List<Lead>>{};
      final names = <String, String>{};
      for (final l in leads) {
        final id = l.assignedUser?.id ?? '_unassigned';
        names[id] = l.assignedUser?.name ?? 'Unassigned';
        (map[id] ??= []).add(l);
      }
      final cols =
          map.entries
              .map(
                (e) => _Column(
                  key: e.key,
                  title: names[e.key] ?? 'Unassigned',
                  leads: _sorted(e.value),
                  color: AppTheme.primaryBlue,
                ),
              )
              .toList()
            ..sort(
              (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
            );
      return cols;
    }
  }

  List<Lead> _sorted(List<Lead> list) {
    if (widget.sort != null) {
      final copy = List<Lead>.from(list)..sort(widget.sort!);
      return copy;
    }
    return list;
  }

  // ── Column widget ───────────────────────────────────────────────────────────

  Widget _buildColumn(
    LeadProvider provider,
    _Column col, {
    int? reorderIndex,
    Key? key,
  }) {
    final total = col.leads.fold<int>(0, (sum, l) => sum + l.potential);

    // Derive a darkened shade of the stage color for text/icons so it reads
    // well against the lightly tinted header background.
    final hsl = HSLColor.fromColor(col.color);
    final darkColor = hsl
        .withLightness((hsl.lightness - 0.18).clamp(0.0, 1.0))
        .toColor();

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

            // Header with subtle stage-color tint
            Container(
              padding: const EdgeInsets.fromLTRB(14, 11, 12, 11),
              decoration: BoxDecoration(
                color: col.color.withValues(alpha: 0.10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          col.title.toUpperCase(),
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
                      if (widget.grouping == BoardGrouping.stage &&
                          widget.onAddLeadToStage != null) ...[
                        InkWell(
                          onTap: () => widget.onAddLeadToStage!(col.key),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: col.color.withValues(alpha: 0.20),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Icon(
                              Icons.add_rounded,
                              size: 16,
                              color: darkColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      if (reorderIndex != null) ...[
                        ReorderableDragStartListener(
                          index: reorderIndex,
                          child: Icon(
                            Icons.drag_indicator_rounded,
                            size: 18,
                            color: darkColor.withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
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
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _formatCurrency(total),
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: darkColor,
                    ),
                  ),
                ],
              ),
            ),

            // Drop target + cards
            Expanded(
              child: DragTarget<Lead>(
                onWillAcceptWithDetails: (details) =>
                    !_belongsHere(details.data, col),
                onAcceptWithDetails: (details) =>
                    _onDropped(provider, details.data, col),
                builder: (context, candidate, rejected) {
                  return Container(
                    decoration: BoxDecoration(
                      color: candidate.isNotEmpty
                          ? col.color.withValues(alpha: 0.08)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: col.leads.isEmpty
                        ? _emptyColumn(candidate.isNotEmpty)
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
                            itemCount: col.leads.length,
                            itemBuilder: (context, i) =>
                                _draggableCard(col.leads[i]),
                          ),
                  );
                },
              ),
            ),
          ],
        ), // Column
      ), // ClipRRect
    ); // Container
  }

  Widget _emptyColumn(bool active) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          active ? 'Drop here' : 'No leads',
          style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textTertiary),
        ),
      ),
    );
  }

  bool _belongsHere(Lead lead, _Column col) {
    if (widget.grouping == BoardGrouping.stage) return lead.stage == col.key;
    return (lead.assignedUser?.id ?? '_unassigned') == col.key;
  }

  Future<void> _onDropped(LeadProvider provider, Lead lead, _Column col) async {
    try {
      if (widget.grouping == BoardGrouping.stage) {
        await provider.moveBoardLeadToStage(lead, col.key);
        if (mounted) {
          SnackbarHelper.showSuccess(context, 'Moved to ${col.title}');
        }
      } else {
        if (col.key == '_unassigned') {
          await provider.setLeadAssignee(lead, null);
        } else {
          await provider.setLeadAssignee(lead, col.key);
        }
        if (mounted) {
          SnackbarHelper.showSuccess(context, 'Assigned to ${col.title}');
        }
      }
    } catch (e) {
      if (mounted) SnackbarHelper.showError(context, 'Could not move lead');
    }
  }

  // ── Card ────────────────────────────────────────────────────────────────────

  Widget _draggableCard(Lead lead) {
    final card = _LeadBoardCard(
      lead: lead,
      onTap: () => widget.onTapLead(lead),
    );
    return LongPressDraggable<Lead>(
      data: lead,
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(width: 264, child: card),
      ),
      childWhenDragging: Opacity(opacity: 0.4, child: card),
      child: card,
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

class _Column {
  final String key;
  final String title;
  final List<Lead> leads;
  final Color color;
  _Column({
    required this.key,
    required this.title,
    required this.leads,
    required this.color,
  });
}

// ── Board Card ────────────────────────────────────────────────────────────────

class _LeadBoardCard extends StatelessWidget {
  final Lead lead;
  final VoidCallback onTap;

  const _LeadBoardCard({required this.lead, required this.onTap});

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

                // Temperature tag (WARM / HOT / COLD) if present in tags
                if (_temperature != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _tempColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _temperature!.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                        color: _tempColor,
                      ),
                    ),
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
                    // Assignee avatar
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

  String? get _temperature {
    for (final t in lead.tags) {
      final u = t.toUpperCase();
      if (u == 'HOT' || u == 'WARM' || u == 'COLD') return u;
    }
    return null;
  }

  Color get _tempColor {
    switch (_temperature) {
      case 'HOT':
        return const Color(0xFFEF4444);
      case 'WARM':
        return const Color(0xFFF59E0B);
      case 'COLD':
        return const Color(0xFF3B82F6);
      default:
        return AppTheme.textSecondary;
    }
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
