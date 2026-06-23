import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_theme.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../models/lead.dart';
import '../../providers/lead_provider.dart';
import '../../providers/tag_provider.dart';
import '../widgets/empty_state.dart';
import '../widgets/lead_card.dart';
import '../widgets/notification_bell.dart';
import '../widgets/shimmer_loading.dart';
import 'lead_activities_screen.dart';
import 'lead_board_view.dart';
import 'lead_bulk_actions.dart';
import 'lead_detail_screen.dart';
import 'lead_form_screen.dart';

/// Sort options for the board toolbar.
enum LeadSort { lastModified, oldest, valueHigh, valueLow, nameAz }

extension LeadSortLabel on LeadSort {
  String get label => switch (this) {
        LeadSort.lastModified => 'Last Modified',
        LeadSort.oldest => 'Oldest First',
        LeadSort.valueHigh => 'Value: High → Low',
        LeadSort.valueLow => 'Value: Low → High',
        LeadSort.nameAz => 'Name: A → Z',
      };
}

/// Main lead listing screen with search, filter, pagination, and CRUD actions.
class LeadListScreen extends StatefulWidget {
  const LeadListScreen({super.key});

  @override
  State<LeadListScreen> createState() => _LeadListScreenState();
}

class _LeadListScreenState extends State<LeadListScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  Timer? _autoRefreshTimer;
  bool _showSearch = false;

  // ── Board / toolbar state ──────────────────────────────────────────
  bool _boardMode = false;
  BoardGrouping _grouping = BoardGrouping.stage;
  String? _filterAssigneeId;
  final Set<String> _filterTags = {};
  final Set<String> _selectedPipelines = {};
  DateTimeRange? _dateRange;
  LeadSort _sort = LeadSort.lastModified;

  // ── Bulk Assign state ───────────────────────────────────────────────
  bool _bulkMode = false;
  final Set<String> _selectedIds = {};
  String? _bulkAssigneeId;
  bool _bulkApplying = false;

  bool get _hasToolbarFilters =>
      _filterAssigneeId != null ||
      _filterTags.isNotEmpty ||
      _dateRange != null ||
      _sort != LeadSort.lastModified;

  /// Client-side predicate applied to board leads from the toolbar.
  bool _boardFilter(Lead lead) {
    if (_filterAssigneeId != null) {
      if (_filterAssigneeId == '_unassigned') {
        if (lead.assignedUser != null) return false;
      } else if (lead.assignedUser?.id != _filterAssigneeId) {
        return false;
      }
    }
    if (_filterTags.isNotEmpty &&
        !_filterTags.any((t) => lead.tags.contains(t))) {
      return false;
    }
    if (_dateRange != null) {
      final d = lead.since;
      if (d.isBefore(_dateRange!.start) ||
          d.isAfter(_dateRange!.end.add(const Duration(days: 1)))) {
        return false;
      }
    }
    return true;
  }

  int _boardSort(Lead a, Lead b) => switch (_sort) {
        LeadSort.lastModified => b.since.compareTo(a.since),
        LeadSort.oldest => a.since.compareTo(b.since),
        LeadSort.valueHigh => b.potential.compareTo(a.potential),
        LeadSort.valueLow => a.potential.compareTo(b.potential),
        LeadSort.nameAz =>
          a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
      };

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<LeadProvider>();
      provider.loadLeads();
      provider.loadSupportingData();
      context.read<TagProvider>().loadTags();
    });
    _autoRefreshTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (mounted) context.read<LeadProvider>().loadLeads();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<LeadProvider>().loadMore();
    }
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      context.read<LeadProvider>().search(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: _buildAppBar(),
      body: _boardMode
          ? Column(
              children: [
                _buildBoardToolbar(),
                Expanded(
                  child: LeadBoardView(
                    grouping: _grouping,
                    filter: _boardFilter,
                    sort: _boardSort,
                    pipelines: _selectedPipelines,
                    onTapLead: (lead) => _navigateToDetail(context, lead),
                    onAddLeadToStage: _createLeadInStage,
                  ),
                ),
              ],
            )
          : Column(
              children: [
                // ── Stage Filter Chips ────────────────────────────────
                _buildStageFilters(),

                // ── Bulk-assign bar OR filter/sort chips ──────────────
                if (_bulkMode) _buildBulkBar() else _buildListFilterBar(),

                // ── Lead List ─────────────────────────────────────────
                Expanded(child: _buildLeadList()),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToForm(context),
        icon: const Icon(Icons.add_rounded),
        label: Text(
          'New Lead',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  // ── List filter bar (sort + assignee + tags + date + bulk assign) ───────────

  Widget _buildListFilterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _toolChip(
              label: 'Bulk Assign',
              icon: Icons.people_alt_outlined,
              active: false,
              onTap: _enterBulkMode,
            ),
            const SizedBox(width: 8),
            _toolChip(
              label: _sort.label,
              icon: Icons.swap_vert_rounded,
              active: _sort != LeadSort.lastModified,
              onTap: _openSortSheet,
            ),
            const SizedBox(width: 8),
            _toolChip(
              label: _filterAssigneeId == null
                  ? 'Assignee'
                  : _assigneeLabel(_filterAssigneeId!),
              icon: Icons.person_outline_rounded,
              active: _filterAssigneeId != null,
              onTap: _openAssigneeSheet,
            ),
            const SizedBox(width: 8),
            _toolChip(
              label: _filterTags.isEmpty ? 'Tags' : 'Tags (${_filterTags.length})',
              icon: Icons.label_outline_rounded,
              active: _filterTags.isNotEmpty,
              onTap: _openTagsSheet,
            ),
            const SizedBox(width: 8),
            _toolChip(
              label: _dateRange == null
                  ? 'Date'
                  : '${_d(_dateRange!.start)} – ${_d(_dateRange!.end)}',
              icon: Icons.calendar_today_rounded,
              active: _dateRange != null,
              onTap: _pickDateRange,
            ),
            if (_hasToolbarFilters) ...[
              const SizedBox(width: 8),
              _toolChip(
                label: 'Clear',
                icon: Icons.close_rounded,
                active: false,
                onTap: () => setState(() {
                  _filterAssigneeId = null;
                  _filterTags.clear();
                  _dateRange = null;
                  _sort = LeadSort.lastModified;
                }),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Bulk-assign action bar ──────────────────────────────────────────────────

  Widget _buildBulkBar() {
    final users = context.read<LeadProvider>().users;
    final assigneeName = _bulkAssigneeId == null
        ? 'Select assignee'
        : (_bulkAssigneeId == '_unassigned'
            ? 'Unassigned'
            : (users.where((u) => u.id == _bulkAssigneeId).isNotEmpty
                ? users.firstWhere((u) => u.id == _bulkAssigneeId).name
                : 'Select assignee'));

    return Container(
      color: AppTheme.primaryBlue.withValues(alpha: 0.06),
      padding: const EdgeInsets.fromLTRB(14, 8, 12, 8),
      child: Row(
        children: [
          Text(
            'Selected: ${_selectedIds.length}',
            style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              onTap: _openBulkAssigneeSheet,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        assigneeName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _bulkAssigneeId == null
                              ? AppTheme.textTertiary
                              : AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    Icon(Icons.keyboard_arrow_down_rounded,
                        size: 18, color: AppTheme.textSecondary),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: _bulkApplying ? null : _cancelBulkMode,
            child: Text('Cancel',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: (_selectedIds.isEmpty ||
                    _bulkAssigneeId == null ||
                    _bulkApplying)
                ? null
                : _applyBulkAssign,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: _bulkApplying
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Text('Apply',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _enterBulkMode() {
    setState(() {
      _bulkMode = true;
      _selectedIds.clear();
      _bulkAssigneeId = null;
    });
  }

  void _cancelBulkMode() {
    setState(() {
      _bulkMode = false;
      _selectedIds.clear();
      _bulkAssigneeId = null;
    });
  }

  void _toggleSelect(Lead lead) {
    setState(() {
      if (_selectedIds.contains(lead.id)) {
        _selectedIds.remove(lead.id);
      } else {
        _selectedIds.add(lead.id);
      }
    });
  }

  void _openBulkAssigneeSheet() {
    final users = context.read<LeadProvider>().users;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _sheetTitle('Assign selected to'),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  _selectableRow(
                    label: 'Unassigned',
                    selected: _bulkAssigneeId == '_unassigned',
                    onTap: () {
                      setState(() => _bulkAssigneeId = '_unassigned');
                      Navigator.pop(ctx);
                    },
                  ),
                  ...users.map((u) => _selectableRow(
                        label: u.name,
                        selected: _bulkAssigneeId == u.id,
                        onTap: () {
                          setState(() => _bulkAssigneeId = u.id);
                          Navigator.pop(ctx);
                        },
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _applyBulkAssign() async {
    final provider = context.read<LeadProvider>();
    final userId = _bulkAssigneeId == '_unassigned' ? null : _bulkAssigneeId;
    setState(() => _bulkApplying = true);
    try {
      await provider.bulkAssign(_selectedIds.toList(), userId);
      provider.loadLeads(refresh: true);
      provider.loadBoardLeads(refresh: true);
      if (mounted) {
        SnackbarHelper.showSuccess(
            context, '${_selectedIds.length} leads reassigned');
        _cancelBulkMode();
      }
    } catch (e) {
      if (mounted) SnackbarHelper.showError(context, 'Bulk assign failed');
    } finally {
      if (mounted) setState(() => _bulkApplying = false);
    }
  }

  // ── Board toolbar (group-by + filters + sort) ───────────────────────────────

  Widget _buildBoardToolbar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        children: [
          // Group-by segmented control
          Row(
            children: [
              Expanded(
                child: _segment(
                  label: 'Group by Stage',
                  icon: Icons.view_column_rounded,
                  selected: _grouping == BoardGrouping.stage,
                  onTap: () =>
                      setState(() => _grouping = BoardGrouping.stage),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _segment(
                  label: 'Group by Assignee',
                  icon: Icons.person_rounded,
                  selected: _grouping == BoardGrouping.assignee,
                  onTap: () =>
                      setState(() => _grouping = BoardGrouping.assignee),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Filter / sort chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _toolChip(
                  label: _sort.label,
                  icon: Icons.swap_vert_rounded,
                  active: _sort != LeadSort.lastModified,
                  onTap: _openSortSheet,
                ),
                const SizedBox(width: 8),
                _toolChip(
                  label: _filterAssigneeId == null
                      ? 'Assignee'
                      : _assigneeLabel(_filterAssigneeId!),
                  icon: Icons.people_alt_rounded,
                  active: _filterAssigneeId != null,
                  onTap: _openAssigneeSheet,
                ),
                const SizedBox(width: 8),
                _toolChip(
                  label: _filterTags.isEmpty
                      ? 'Tags'
                      : 'Tags (${_filterTags.length})',
                  icon: Icons.label_outline_rounded,
                  active: _filterTags.isNotEmpty,
                  onTap: _openTagsSheet,
                ),
                const SizedBox(width: 8),
                _toolChip(
                  label: _dateRange == null
                      ? 'Date'
                      : '${_d(_dateRange!.start)} – ${_d(_dateRange!.end)}',
                  icon: Icons.calendar_today_rounded,
                  active: _dateRange != null,
                  onTap: _pickDateRange,
                ),
                // Pipeline filter — only meaningful when grouping by stage.
                if (_grouping == BoardGrouping.stage) ...[
                  const SizedBox(width: 8),
                  _toolChip(
                    label: _selectedPipelines.isEmpty
                        ? 'Pipeline'
                        : _selectedPipelines.length == 1
                            ? _selectedPipelines.first
                            : 'Pipelines (${_selectedPipelines.length})',
                    icon: Icons.account_tree_rounded,
                    active: _selectedPipelines.isNotEmpty,
                    onTap: _openPipelineSheet,
                  ),
                ],
                if (_hasToolbarFilters || _selectedPipelines.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  _toolChip(
                    label: 'Clear',
                    icon: Icons.close_rounded,
                    active: false,
                    onTap: () => setState(() {
                      _filterAssigneeId = null;
                      _filterTags.clear();
                      _selectedPipelines.clear();
                      _dateRange = null;
                      _sort = LeadSort.lastModified;
                    }),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _segment({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryBlue : const Color(0xFFF1F4F9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 16,
                color: selected ? Colors.white : AppTheme.textSecondary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : AppTheme.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _toolChip({
    required String label,
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active
              ? AppTheme.primaryBlue.withValues(alpha: 0.1)
              : const Color(0xFFF1F4F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active
                ? AppTheme.primaryBlue.withValues(alpha: 0.4)
                : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 15,
                color: active ? AppTheme.primaryBlue : AppTheme.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: active ? AppTheme.primaryBlue : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _d(DateTime d) => '${d.day}/${d.month}';

  String _assigneeLabel(String id) {
    if (id == '_unassigned') return 'Unassigned';
    final users = context.read<LeadProvider>().users;
    final u = users.where((u) => u.id == id);
    return u.isNotEmpty ? u.first.name : 'Assignee';
  }

  // ── Toolbar sheets ──────────────────────────────────────────────────────────

  void _openSortSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _sheetTitle('Sort by'),
            ...LeadSort.values.map((s) => _selectableRow(
                  label: s.label,
                  selected: _sort == s,
                  onTap: () {
                    setState(() => _sort = s);
                    Navigator.pop(ctx);
                  },
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _openAssigneeSheet() {
    final users = context.read<LeadProvider>().users;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _sheetTitle('Filter by assignee'),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  _selectableRow(
                    label: 'All',
                    selected: _filterAssigneeId == null,
                    onTap: () {
                      setState(() => _filterAssigneeId = null);
                      Navigator.pop(ctx);
                    },
                  ),
                  _selectableRow(
                    label: 'Unassigned',
                    selected: _filterAssigneeId == '_unassigned',
                    onTap: () {
                      setState(() => _filterAssigneeId = '_unassigned');
                      Navigator.pop(ctx);
                    },
                  ),
                  ...users.map((u) => _selectableRow(
                        label: u.name,
                        selected: _filterAssigneeId == u.id,
                        onTap: () {
                          setState(() => _filterAssigneeId = u.id);
                          Navigator.pop(ctx);
                        },
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openTagsSheet() {
    // Use the org's tag list as the source of truth, merged with any tags
    // present on already-loaded leads (covers legacy free-text tags too).
    final provider = context.read<LeadProvider>();
    final tagProvider = context.read<TagProvider>();
    final allTags = <String>{
      ...tagProvider.tagNames,
      for (final l in provider.boardLeads) ...l.tags,
      for (final l in provider.leads) ...l.tags,
    }.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _sheetTitle('Filter by tags'),
              if (allTags.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text('No tags found',
                      style: GoogleFonts.inter(
                          color: AppTheme.textSecondary)),
                )
              else
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: allTags
                        .map((t) => CheckboxListTile(
                              value: _filterTags.contains(t),
                              activeColor: AppTheme.primaryBlue,
                              title: Text(t,
                                  style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500)),
                              onChanged: (v) {
                                setSheet(() {
                                  if (v == true) {
                                    _filterTags.add(t);
                                  } else {
                                    _filterTags.remove(t);
                                  }
                                });
                                setState(() {});
                              },
                            ))
                        .toList(),
                  ),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _openPipelineSheet() {
    final pipelines = context.read<LeadProvider>().pipelines;
    if (pipelines.isEmpty) {
      SnackbarHelper.showError(context, 'No pipelines found for this org');
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _sheetTitle('Filter by pipeline'),
              // Select All row
              CheckboxListTile(
                value: _selectedPipelines.length == pipelines.length,
                tristate: false,
                activeColor: AppTheme.primaryBlue,
                title: Text('Select All',
                    style: GoogleFonts.inter(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                onChanged: (v) {
                  setSheet(() {
                    if (v == true) {
                      _selectedPipelines
                        ..clear()
                        ..addAll(pipelines);
                    } else {
                      _selectedPipelines.clear();
                    }
                  });
                  setState(() {});
                },
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: pipelines
                      .map((p) => CheckboxListTile(
                            value: _selectedPipelines.contains(p),
                            activeColor: AppTheme.primaryBlue,
                            title: Text(p,
                                style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500)),
                            onChanged: (v) {
                              setSheet(() {
                                if (v == true) {
                                  _selectedPipelines.add(p);
                                } else {
                                  _selectedPipelines.remove(p);
                                }
                              });
                              setState(() {});
                            },
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 2),
      initialDateRange: _dateRange,
    );
    if (picked != null) setState(() => _dateRange = picked);
  }

  Widget _sheetTitle(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Text(text,
              style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary)),
        ],
      ),
    );
  }

  Widget _selectableRow({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      title: Text(label,
          style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? AppTheme.primaryBlue : AppTheme.textPrimary)),
      trailing: selected
          ? Icon(Icons.check_rounded, color: AppTheme.primaryBlue, size: 20)
          : null,
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      leading: IconButton(
        icon: const Icon(Icons.menu_rounded, color: AppTheme.textPrimary),
        onPressed: () => Scaffold.of(context).openDrawer(),
      ),
      title: _showSearch
          ? TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search leads...',
                hintStyle: GoogleFonts.inter(
                  color: AppTheme.textTertiary,
                  fontSize: 16,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
              ),
              style: GoogleFonts.inter(
                fontSize: 16,
                color: AppTheme.textPrimary,
              ),
            )
          : Row(
              children: [
                Text(
                  'Leads',
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                Consumer<LeadProvider>(
                  builder: (context, provider, child) {
                    if (provider.totalCount > 0) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${provider.totalCount}',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
      actions: [
        if (!_showSearch) ...[
          // List / Board view toggle
          IconButton(
            tooltip: _boardMode ? 'List view' : 'Board view',
            icon: Icon(
              _boardMode
                  ? Icons.view_list_rounded
                  : Icons.view_kanban_rounded,
              color: AppTheme.textSecondary,
            ),
            onPressed: () => setState(() {
              _boardMode = !_boardMode;
              if (_boardMode) {
                _bulkMode = false;
                _selectedIds.clear();
              }
            }),
          ),
          // Export / Bulk upload menu
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded,
                color: AppTheme.textSecondary),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            onSelected: (v) {
              if (v == 'export') {
                LeadBulkActions.exportExcel(context);
              } else if (v == 'bulk') {
                _runBulkUpload();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'export',
                child: _menuRow(Icons.download_rounded, 'Export CSV'),
              ),
              PopupMenuItem(
                value: 'bulk',
                child: _menuRow(Icons.upload_file_rounded, 'Bulk Upload'),
              ),
            ],
          ),
        ],
        IconButton(
          icon: Icon(
            _showSearch ? Icons.close_rounded : Icons.search_rounded,
            color: AppTheme.textSecondary,
          ),
          onPressed: () {
            setState(() {
              _showSearch = !_showSearch;
              if (!_showSearch) {
                _searchController.clear();
                context.read<LeadProvider>().search('');
              }
            });
          },
        ),
        if (!_showSearch) const NotificationBell(),
      ],
      bottom: _showSearch
          ? null
          : PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(
                height: 1,
                color: const Color(0xFFE5E7EB),
              ),
            ),
    );
  }

  Widget _menuRow(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 19, color: AppTheme.textSecondary),
        const SizedBox(width: 12),
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimary)),
      ],
    );
  }

  /// Open the New Lead form with a stage pre-selected (board column "+").
  void _createLeadInStage(String stage) {
    final provider = context.read<LeadProvider>();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LeadFormScreen(initialStage: stage),
      ),
    ).then((result) {
      if (result == true) {
        provider.loadLeads(refresh: true);
        provider.loadBoardLeads(refresh: true);
      }
    });
  }

  Future<void> _runBulkUpload() async {
    final uploaded = await LeadBulkActions.bulkUpload(context);
    if (uploaded && mounted) {
      final provider = context.read<LeadProvider>();
      provider.loadLeads(refresh: true);
      provider.loadBoardLeads(refresh: true);
    }
  }

  // ── Per-lead quick actions (list view) ──────────────────────────────────────

  void _openLeadActions(BuildContext context, Lead lead) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      lead.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
            _actionTile(ctx, Icons.event_note_rounded, 'Log Activity',
                const Color(0xFF1A73E8), () {
              Navigator.pop(ctx);
              _openActivities(lead);
            }),
            _actionTile(ctx, Icons.visibility_rounded, 'View',
                const Color(0xFF6B7280), () {
              Navigator.pop(ctx);
              _navigateToDetail(context, lead);
            }),
            _actionTile(ctx, Icons.edit_rounded, 'Edit',
                const Color(0xFF8B5CF6), () {
              Navigator.pop(ctx);
              _navigateToForm(context, lead: lead);
            }),
            _actionTile(ctx, Icons.person_add_alt_rounded, 'Reassign',
                const Color(0xFF0EA5E9), () {
              Navigator.pop(ctx);
              _reassignLead(lead);
            }),
            _actionTile(ctx, Icons.delete_outline_rounded, 'Delete',
                const Color(0xFFEF4444), () {
              Navigator.pop(ctx);
              _confirmDelete(lead);
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _actionTile(BuildContext ctx, IconData icon, String label, Color color,
      VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(label,
          style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary)),
    );
  }

  void _openActivities(Lead lead) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LeadActivitiesScreen(
          leadId: lead.id,
          leadName: lead.displayName,
          assignedUserId: lead.assignedUser?.id ?? '',
          mobile: lead.business.mobile,
          email: lead.business.email,
          stage: lead.stage,
          businessId: lead.business.id,
        ),
      ),
    );
  }

  void _reassignLead(Lead lead) {
    final users = context.read<LeadProvider>().users;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _sheetTitle('Reassign to'),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  _selectableRow(
                    label: 'Unassigned',
                    selected: lead.assignedUser == null,
                    onTap: () {
                      Navigator.pop(ctx);
                      _applyReassign(lead, null);
                    },
                  ),
                  ...users.map((u) => _selectableRow(
                        label: u.name,
                        selected: lead.assignedUser?.id == u.id,
                        onTap: () {
                          Navigator.pop(ctx);
                          _applyReassign(lead, u.id);
                        },
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _applyReassign(Lead lead, String? userId) async {
    final provider = context.read<LeadProvider>();
    try {
      await provider.setLeadAssignee(lead, userId);
      provider.loadLeads(refresh: true);
      if (mounted) SnackbarHelper.showSuccess(context, 'Lead reassigned');
    } catch (e) {
      if (mounted) SnackbarHelper.showError(context, 'Could not reassign lead');
    }
  }

  void _confirmDelete(Lead lead) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete_outline_rounded,
                    color: Color(0xFFEF4444), size: 28),
              ),
              const SizedBox(height: 16),
              Text('Delete Lead',
                  style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary)),
              const SizedBox(height: 8),
              Text(
                'Delete "${lead.displayName}"? This cannot be undone.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 14, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                      child: Text('Cancel',
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _applyDelete(lead);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text('Delete',
                          style:
                              GoogleFonts.inter(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _applyDelete(Lead lead) async {
    final provider = context.read<LeadProvider>();
    try {
      await provider.deleteLead(lead.id);
      provider.loadBoardLeads(refresh: true);
      if (mounted) SnackbarHelper.showSuccess(context, 'Lead deleted');
    } catch (e) {
      if (mounted) SnackbarHelper.showError(context, 'Could not delete lead');
    }
  }

  Widget _buildStageFilters() {
    return Consumer<LeadProvider>(
      builder: (context, provider, _) {
        if (provider.stages.isEmpty) return const SizedBox.shrink();

        return Container(
          color: Colors.white,
          child: Column(
            children: [
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    // "All" chip
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 8,
                      ),
                      child: FilterChip(
                        label: Text(
                          'All',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: provider.selectedStage == null
                                ? Colors.white
                                : AppTheme.textSecondary,
                          ),
                        ),
                        selected: provider.selectedStage == null,
                        onSelected: (_) => provider.filterByStage(null),
                        selectedColor: AppTheme.primaryBlue,
                        checkmarkColor: Colors.white,
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: provider.selectedStage == null
                                ? AppTheme.primaryBlue
                                : const Color(0xFFF3F4F6),
                            width: 1.5,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),

                    // Stage chips
                    ...provider.stages.map((stage) {
                      final isSelected =
                          provider.selectedStage == stage.stage;
                      final stageColor =
                          AppTheme.stageColor(stage.stage);
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 8,
                        ),
                        child: FilterChip(
                          label: Text(
                            stage.stage,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isSelected
                                  ? stageColor
                                  : AppTheme.textSecondary,
                            ),
                          ),
                          selected: isSelected,
                          onSelected: (_) =>
                              provider.filterByStage(stage.stage),
                          selectedColor:
                              stageColor.withValues(alpha: 0.12),
                          checkmarkColor: stageColor,
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: isSelected
                                  ? stageColor.withValues(alpha: 0.5)
                                  : const Color(0xFFF3F4F6),
                              width: 1.5,
                            ),
                          ),
                          padding:
                              const EdgeInsets.symmetric(horizontal: 4),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                      );
                    }),
                  ],
                ),
              ),
              Container(height: 1, color: const Color(0xFFE5E7EB)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLeadList() {
    return Consumer<LeadProvider>(
      builder: (context, provider, _) {
        // Loading state
        if (provider.isLoading) {
          return const ShimmerLoading();
        }

        // Error state
        if (provider.error != null && provider.leads.isEmpty) {
          return EmptyState(
            title: 'Something went wrong',
            subtitle: provider.error!,
            icon: Icons.error_outline_rounded,
            actionLabel: 'Retry',
            onAction: () => provider.loadLeads(refresh: true),
          );
        }

        // Empty state
        if (provider.leads.isEmpty) {
          return EmptyState(
            title: provider.searchQuery.isNotEmpty ||
                    provider.selectedStage != null
                ? 'No matching leads'
                : 'No leads yet',
            subtitle: provider.searchQuery.isNotEmpty ||
                    provider.selectedStage != null
                ? 'Try adjusting your search or filters'
                : 'Tap + to create your first lead',
            icon: provider.searchQuery.isNotEmpty
                ? Icons.search_off_rounded
                : Icons.people_outline_rounded,
            actionLabel: provider.searchQuery.isNotEmpty ||
                    provider.selectedStage != null
                ? 'Clear Filters'
                : null,
            onAction: provider.searchQuery.isNotEmpty ||
                    provider.selectedStage != null
                ? () => provider.clearFilters()
                : null,
          );
        }

        // Apply the toolbar filters + sort client-side over the loaded leads.
        final displayed = provider.leads.where(_boardFilter).toList()
          ..sort(_boardSort);

        if (displayed.isEmpty) {
          return EmptyState(
            title: 'No matching leads',
            subtitle: 'Try adjusting your filters',
            icon: Icons.filter_alt_off_rounded,
          );
        }

        // Pagination loader only when no client filters narrow the set.
        final showLoader = provider.hasMore && !_hasToolbarFilters;

        return RefreshIndicator(
          onRefresh: () => provider.loadLeads(refresh: true),
          color: AppTheme.primaryBlue,
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.only(top: 8, bottom: 80),
            itemCount: displayed.length + (showLoader ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == displayed.length) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  ),
                );
              }

              final lead = displayed[index];
              return LeadCard(
                lead: lead,
                selectionMode: _bulkMode,
                selected: _selectedIds.contains(lead.id),
                onTap: _bulkMode
                    ? () => _toggleSelect(lead)
                    : () => _navigateToDetail(context, lead),
                onMarkWon: () => _confirmStageChange(context, lead, won: true),
                onMarkLost: () => _confirmStageChange(context, lead, won: false),
                onMore: _bulkMode ? null : () => _openLeadActions(context, lead),
              );
            },
          ),
        );
      },
    );
  }

  void _navigateToDetail(BuildContext context, Lead lead) {
    final provider = context.read<LeadProvider>();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LeadDetailScreen(lead: lead),
      ),
    ).then((_) {
      // Refresh list when returning from detail (may have edited/deleted)
      provider.loadLeads(refresh: true);
    });
  }

  void _navigateToForm(BuildContext context, {Lead? lead}) {
    final provider = context.read<LeadProvider>();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LeadFormScreen(lead: lead),
      ),
    ).then((result) {
      if (result == true) {
        provider.loadLeads(refresh: true);
      }
    });
  }

  /// Modern confirmation dialog for marking a lead Won / Lost via swipe.
  void _confirmStageChange(BuildContext context, Lead lead,
      {required bool won}) {
    final Color accent =
        won ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    final Color accentDark =
        won ? const Color(0xFF059669) : const Color(0xFFDC2626);
    final IconData icon =
        won ? Icons.emoji_events_rounded : Icons.do_not_disturb_on_rounded;
    final String title = won ? 'Mark as Won' : 'Mark as Lost';
    final String message = won
        ? 'Move this lead to the Won stage? This marks the deal as successfully closed.'
        : 'Move this lead to the Lost stage? This marks the deal as closed without a win.';

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Gradient icon
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [accent, accentDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 34),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 10),
              // Lead name chip
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  lead.displayName,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF334155),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF6B7280),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 26),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF374151),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _applyStageChange(context, lead, won: won);
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _applyStageChange(BuildContext context, Lead lead,
      {required bool won}) async {
    final provider = context.read<LeadProvider>();
    final stage = won ? provider.wonStageName : provider.lostStageName;
    try {
      await provider.setLeadStage(lead, stage);
      if (context.mounted) {
        SnackbarHelper.showSuccess(
          context,
          won ? 'Lead marked as Won 🎉' : 'Lead marked as Lost',
        );
      }
    } catch (e) {
      if (context.mounted) {
        SnackbarHelper.showError(context, e.toString());
      }
    }
  }
}
