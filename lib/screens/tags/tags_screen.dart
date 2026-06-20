import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_theme.dart';
import '../../models/lead.dart';
import '../../models/tag.dart';
import '../../providers/lead_provider.dart';
import '../../providers/tag_provider.dart';
import '../leads/lead_detail_screen.dart';
import '../leads/lead_form_screen.dart';
import '../main_navigation_screen.dart';
import 'tag_board_view.dart';

/// Tag filter applied to the management list.
enum _TagFilter { all, inUse, unused }

/// Tags screen (menubar destination) — mirrors the web Tags dashboard:
/// stat cards, search, In use / Unused filters, per-tag usage bars, and
/// create / rename / delete actions. Usage counts are derived from the leads
/// loaded by [LeadProvider] so the numbers stay consistent with the board.
class TagsScreen extends StatefulWidget {
  const TagsScreen({super.key});

  @override
  State<TagsScreen> createState() => _TagsScreenState();
}

class _TagsScreenState extends State<TagsScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  _TagFilter _filter = _TagFilter.all;
  bool _boardMode = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TagProvider>().loadTags();
      // Board leads power the usage counts; load them if not already cached.
      context.read<LeadProvider>().loadBoardLeads();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    await Future.wait([
      context.read<TagProvider>().loadTags(refresh: true),
      context.read<LeadProvider>().loadBoardLeads(refresh: true),
    ]);
  }

  // ── Create / Rename / Delete ─────────────────────────────────────

  Future<void> _addTag() async {
    final provider = context.read<TagProvider>();
    final name = await _showNameDialog();
    if (name == null || name.trim().isEmpty) return;
    try {
      await provider.createTag(name.trim());
      _showSnack('Tag created', success: true);
    } catch (e) {
      _showSnack(e.toString());
    }
  }

  Future<void> _renameTag(Tag tag) async {
    final provider = context.read<TagProvider>();
    final name = await _showNameDialog(
      title: 'Rename Tag',
      initial: tag.name,
      confirmLabel: 'Save',
    );
    final newName = name?.trim();
    if (newName == null || newName.isEmpty || newName == tag.name) return;
    try {
      await provider.updateTag(tag.id, newName);
      _showSnack('Tag renamed', success: true);
    } catch (e) {
      _showSnack(e.toString());
    }
  }

  Future<void> _deleteTag(TagUsage usage) async {
    final provider = context.read<TagProvider>();
    final confirmed = await _showDeleteConfirm(usage);
    if (!confirmed) return;
    try {
      await provider.deleteTag(usage.tag.id);
      _showSnack('Tag deleted', success: true);
    } catch (e) {
      _showSnack(e.toString());
    }
  }

  // ── Navigation ───────────────────────────────────────────────────

  /// Jump to the Leads tab in the main navigation.
  void _goToLeads() {
    MainNavigationScreen.goToTab(1);
    Navigator.pop(context);
  }

  /// Open a lead's detail screen, refreshing the board on return.
  void _openLead(Lead lead) {
    final provider = context.read<LeadProvider>();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LeadDetailScreen(lead: lead)),
    ).then((_) {
      if (mounted) provider.loadBoardLeads(refresh: true);
    });
  }

  // ── Tag board column actions ─────────────────────────────────────

  /// "+" on a tag column → create a lead pre-tagged with this tag.
  void _addLeadWithTag(String tagName) {
    final provider = context.read<LeadProvider>();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LeadFormScreen(initialTags: {tagName})),
    ).then((result) {
      if (result == true && mounted) provider.loadBoardLeads(refresh: true);
    });
  }

  /// 3-dot menu action dispatcher for a tag column.
  void _onColumnAction(String tagName, TagColumnAction action) {
    switch (action) {
      case TagColumnAction.rename:
        _renameTagFromBoard(tagName);
      case TagColumnAction.clear:
        _clearTagFromBoard(tagName);
      case TagColumnAction.delete:
        _deleteTagFromBoard(tagName);
    }
  }

  /// Resolve the org Tag entity for a name (null for free-text-only tags).
  Tag? _orgTag(String name) {
    final match = context.read<TagProvider>().tags.where((t) => t.name == name);
    return match.isEmpty ? null : match.first;
  }

  Future<void> _renameTagFromBoard(String tagName) async {
    final tagProvider = context.read<TagProvider>();
    final leadProvider = context.read<LeadProvider>();
    final newName = (await _showNameDialog(
      title: 'Rename Tag',
      initial: tagName,
      confirmLabel: 'Save',
    ))?.trim();
    if (newName == null || newName.isEmpty || newName == tagName) return;
    final tag = _orgTag(tagName);
    await _runBusy(() async {
      if (tag != null) await tagProvider.updateTag(tag.id, newName);
      await leadProvider.renameTagOnAllLeads(tagName, newName);
      await tagProvider.loadTags(refresh: true);
    }, success: 'Tag renamed');
  }

  Future<void> _clearTagFromBoard(String tagName) async {
    final leadProvider = context.read<LeadProvider>();
    final count = leadProvider.boardLeads
        .where((l) => l.tags.contains(tagName))
        .length;
    if (count == 0) {
      _showSnack('No leads carry "$tagName"');
      return;
    }
    final confirmed = await _showActionConfirm(
      icon: Icons.layers_clear_rounded,
      iconColor: const Color(0xFFF59E0B),
      title: 'Clear all cards',
      message:
          'Remove "$tagName" from $count lead${count == 1 ? '' : 's'}? The tag stays; the leads are not deleted.',
      confirmLabel: 'Clear',
    );
    if (!confirmed) return;
    await _runBusy(
      () => leadProvider.removeTagFromAllLeads(tagName),
      success: 'Cleared "$tagName" from all leads',
    );
  }

  Future<void> _deleteTagFromBoard(String tagName) async {
    final tagProvider = context.read<TagProvider>();
    final leadProvider = context.read<LeadProvider>();
    final count = leadProvider.boardLeads
        .where((l) => l.tags.contains(tagName))
        .length;
    final confirmed = await _showActionConfirm(
      icon: Icons.delete_outline_rounded,
      iconColor: const Color(0xFFEF4444),
      title: 'Delete Tag',
      message: count > 0
          ? 'Delete "$tagName"? It will be removed from $count lead${count == 1 ? '' : 's'}. The leads are not deleted.'
          : 'Are you sure you want to delete "$tagName"?',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed) return;
    final tag = _orgTag(tagName);
    await _runBusy(() async {
      if (count > 0) await leadProvider.removeTagFromAllLeads(tagName);
      if (tag != null) await tagProvider.deleteTag(tag.id);
    }, success: 'Tag deleted');
  }

  /// Run an async action behind a blocking spinner, then snack the result.
  Future<void> _runBusy(
    Future<void> Function() action, {
    required String success,
  }) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      await action();
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      _showSnack(success, success: true);
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      _showSnack(e.toString());
    }
  }

  // ── Build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Tags',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        actions: [
          // List / Board view toggle
          IconButton(
            tooltip: _boardMode ? 'List view' : 'Board view',
            icon: Icon(
              _boardMode ? Icons.view_list_rounded : Icons.view_kanban_rounded,
              size: 22,
              color: AppTheme.textSecondary,
            ),
            onPressed: () => setState(() => _boardMode = !_boardMode),
          ),
          Consumer<TagProvider>(
            builder: (context, p, child) => p.isSaving
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 22),
                    onPressed: _refresh,
                  ),
          ),
          // Go to Leads
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: _goToLeads,
              icon: const Icon(Icons.arrow_forward_rounded, size: 16),
              label: Text(
                'Leads',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primaryBlue,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFF3F4F6)),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addTag,
        backgroundColor: AppTheme.primaryBlue,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          'Add Tag',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: _boardMode
          ? TagBoardView(
              onTapLead: _openLead,
              onAddLead: _addLeadWithTag,
              onColumnAction: _onColumnAction,
            )
          : Consumer2<TagProvider, LeadProvider>(
              builder: (context, tagProvider, leadProvider, _) {
                if (tagProvider.isLoading && !tagProvider.loadedOnce) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (tagProvider.error != null && tagProvider.tags.isEmpty) {
                  return _buildError(tagProvider.error!);
                }

                final usage = tagProvider.usageFrom(leadProvider.boardLeads);
                final taggedLeads = leadProvider.boardLeads
                    .where((l) => l.tags.isNotEmpty)
                    .length;

                final inUseCount = usage.where((u) => u.inUse).length;
                final mostUsed = usage.isNotEmpty && usage.first.leadCount > 0
                    ? usage.first.tag.name
                    : '—';

                // Apply search + filter.
                final filtered = usage.where((u) {
                  if (_query.isNotEmpty &&
                      !u.tag.name.toLowerCase().contains(
                        _query.toLowerCase(),
                      )) {
                    return false;
                  }
                  return switch (_filter) {
                    _TagFilter.all => true,
                    _TagFilter.inUse => u.inUse,
                    _TagFilter.unused => !u.inUse,
                  };
                }).toList();

                return RefreshIndicator(
                  onRefresh: _refresh,
                  color: AppTheme.primaryBlue,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    children: [
                      _buildStatsRow(
                        total: usage.length,
                        inUse: inUseCount,
                        unused: usage.length - inUseCount,
                        mostUsed: mostUsed,
                        taggedLeads: taggedLeads,
                      ),
                      const SizedBox(height: 16),
                      _buildSearch(),
                      const SizedBox(height: 12),
                      _buildFilterTabs(
                        usage.length,
                        inUseCount,
                        usage.length - inUseCount,
                      ),
                      const SizedBox(height: 14),
                      if (filtered.isEmpty)
                        _buildEmpty()
                      else
                        ...filtered.map(
                          (u) => _TagCard(
                            usage: u,
                            onRename: () => _renameTag(u.tag),
                            onDelete: () => _deleteTag(u),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  // ── Stats cards ──────────────────────────────────────────────────

  Widget _buildStatsRow({
    required int total,
    required int inUse,
    required int unused,
    required String mostUsed,
    required int taggedLeads,
  }) {
    return SizedBox(
      height: 112,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _statCard(
            'Total tags',
            '$total',
            Icons.sell_rounded,
            AppTheme.primaryBlue,
          ),
          _statCard(
            'In use',
            '$inUse',
            Icons.check_circle_rounded,
            const Color(0xFF10B981),
          ),
          _statCard(
            'Unused',
            '$unused',
            Icons.remove_circle_outline_rounded,
            const Color(0xFFF59E0B),
          ),
          _statCard(
            'Most used',
            mostUsed,
            Icons.local_fire_department_rounded,
            const Color(0xFFEF4444),
          ),
          _statCard(
            'Tagged leads',
            '$taggedLeads',
            Icons.people_alt_rounded,
            const Color(0xFF8B5CF6),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 17, color: color),
              ),
              const Spacer(),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Search ───────────────────────────────────────────────────────

  Widget _buildSearch() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF3F4F6), width: 1.5),
      ),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _query = v),
        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: 'Search tags...',
          hintStyle: GoogleFonts.inter(
            fontSize: 14,
            color: AppTheme.textTertiary,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 20,
            color: AppTheme.textSecondary,
          ),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _query = '');
                  },
                ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: AppTheme.primaryBlue, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  // ── Filter tabs ──────────────────────────────────────────────────

  Widget _buildFilterTabs(int all, int inUse, int unused) {
    Widget tab(String label, _TagFilter f, int count) {
      final selected = _filter == f;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _filter = f),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: selected ? AppTheme.primaryBlue : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected
                    ? AppTheme.primaryBlue
                    : const Color(0xFFF3F4F6),
                width: 1.5,
              ),
            ),
            child: Text(
              '$label ($count)',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppTheme.textSecondary,
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        tab('All', _TagFilter.all, all),
        tab('In use', _TagFilter.inUse, inUse),
        tab('Unused', _TagFilter.unused, unused),
      ],
    );
  }

  // ── Empty / Error ────────────────────────────────────────────────

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.sell_outlined,
                size: 34,
                color: AppTheme.primaryBlue,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _query.isNotEmpty || _filter != _TagFilter.all
                  ? 'No matching tags'
                  : 'No tags yet',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _query.isNotEmpty || _filter != _TagFilter.all
                  ? 'Try adjusting your search or filter'
                  : 'Tap "Add Tag" to create your first tag',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(String error) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 48,
            color: Colors.red.shade300,
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              error,
              style: GoogleFonts.inter(color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _refresh, child: const Text('Retry')),
        ],
      ),
    );
  }

  // ── Dialogs ──────────────────────────────────────────────────────

  Future<String?> _showNameDialog({
    String title = 'Add Tag',
    String? initial,
    String confirmLabel = 'Add',
  }) {
    final ctrl = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
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
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: 'Tag name (e.g. Hot Lead)',
                  hintStyle: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppTheme.textTertiary,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: AppTheme.primaryBlue,
                      width: 2,
                    ),
                  ),
                ),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                onSubmitted: (v) => Navigator.pop(ctx, v),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.inter(
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, ctrl.text),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    child: Text(
                      confirmLabel,
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700),
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

  /// Generic confirm dialog used by the tag board column actions.
  Future<bool> _showActionConfirm({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String message,
    required String confirmLabel,
    bool destructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
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
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 28),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: destructive
                            ? const Color(0xFFEF4444)
                            : iconColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        confirmLabel,
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700),
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
    return result ?? false;
  }

  Future<bool> _showDeleteConfirm(TagUsage usage) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
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
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: Color(0xFFEF4444),
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Delete Tag',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                usage.leadCount > 0
                    ? 'Delete "${usage.tag.name}"? It is used by ${usage.leadCount} lead${usage.leadCount == 1 ? '' : 's'}. The leads will not be deleted.'
                    : 'Are you sure you want to delete "${usage.tag.name}"?',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        'Delete',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700),
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
    return result ?? false;
  }

  void _showSnack(String msg, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.inter(fontSize: 13)),
        backgroundColor: success
            ? const Color(0xFF10B981)
            : const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}

// ── Tag Card ───────────────────────────────────────────────────────────────

class _TagCard extends StatelessWidget {
  final TagUsage usage;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const _TagCard({
    required this.usage,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.stageColor(usage.tag.name);
    final pct = usage.percentage.round();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.sell_rounded, size: 18, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          usage.tag.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _statusBadge(usage.inUse),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Usage bar
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${usage.leadCount} lead${usage.leadCount == 1 ? '' : 's'}',
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF059669),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$pct%',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (usage.percentage / 100).clamp(0.0, 1.0),
                      minHeight: 5,
                      backgroundColor: const Color(0xFFF1F4F9),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                ],
              ),
            ),
            // Actions
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(
                Icons.edit_outlined,
                size: 19,
                color: AppTheme.textSecondary,
              ),
              onPressed: onRename,
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(
                Icons.delete_outline_rounded,
                size: 19,
                color: Color(0xFFEF4444),
              ),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(bool inUse) {
    final color = inUse ? AppTheme.primaryBlue : AppTheme.textTertiary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        inUse ? 'In use' : 'Unused',
        style: GoogleFonts.inter(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
