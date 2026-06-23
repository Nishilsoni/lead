import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_theme.dart';
import '../../models/lead.dart';
import '../../providers/lead_provider.dart';
import '../../services/lead_service.dart';

class StagePipelineScreen extends StatefulWidget {
  const StagePipelineScreen({super.key});

  @override
  State<StagePipelineScreen> createState() => _StagePipelineScreenState();
}

class _StagePipelineScreenState extends State<StagePipelineScreen> {
  final LeadService _service = LeadService();

  // All stages grouped by pipeline/section
  Map<String, List<LeadStage>> _pipelineStages = {};
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Fetch all stages (API may return them grouped by section)
      final stages = await _service.getLeadStages();

      // Group stages by pipeline section
      final grouped = <String, List<LeadStage>>{};

      // Always show known pipelines even if empty
      for (final p in LeadProvider.knownPipelines) {
        grouped[p] = [];
      }

      for (final stage in stages) {
        final section = (stage.section != null && stage.section!.isNotEmpty)
            ? stage.section!
            : LeadProvider.knownPipelines.first;
        (grouped[section] ??= []).add(stage);
      }

      // Sort stages within each pipeline by order
      for (final key in grouped.keys) {
        grouped[key]!.sort((a, b) => a.order.compareTo(b.order));
      }

      setState(() {
        _pipelineStages = grouped;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  int get _totalStages =>
      _pipelineStages.values.fold(0, (sum, list) => sum + list.length);

  int get _editableStages => _pipelineStages.values
      .expand((list) => list)
      .where((s) => s.id != null)
      .length;

  int get _pipelineCount => _pipelineStages.values
      .where((list) => list.isNotEmpty)
      .length;

  Future<void> _addStage({String? preselectedPipeline}) async {
    final result = await _showAddStageDialog(
        preselectedPipeline: preselectedPipeline);
    if (result == null) return;

    final stageName = result.$1.trim().toUpperCase();
    final pipeline = result.$2;

    if (stageName.isEmpty) return;

    final stagesInPipeline = _pipelineStages[pipeline] ?? [];
    final nextOrder =
        stagesInPipeline.isEmpty ? 1 : stagesInPipeline.last.order + 1;

    setState(() => _saving = true);
    try {
      await _service.createStage(
        name: stageName,
        order: nextOrder,
        section: pipeline,
      );
      await _load();
      if (mounted) context.read<LeadProvider>().refreshStages();
      _showSnack('Stage added', success: true);
    } catch (e) {
      _showSnack(_friendlyError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _renameStage(String pipeline, int index) async {
    final stage = _pipelineStages[pipeline]![index];
    final name = await _showNameDialog(
      title: 'Rename Stage',
      initial: stage.stage,
      confirmLabel: 'Save',
    );
    final newName = name?.trim().toUpperCase();
    if (newName == null || newName.isEmpty || newName == stage.stage) return;

    setState(() => _saving = true);
    try {
      await _service.renameStage(
        fromStage: stage.stage,
        toStage: newName,
        section: stage.section,
      );
      await _load();
      if (mounted) context.read<LeadProvider>().refreshStages();
      _showSnack('Stage renamed', success: true);
    } catch (e) {
      _showSnack(_friendlyError(e));
      await _load();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteStage(String pipeline, int index) async {
    final stage = _pipelineStages[pipeline]![index];
    final confirmed = await _showDeleteConfirm(stage.stage);
    if (!confirmed) return;

    if (stage.id == null) {
      _showSnack('Cannot delete: stage ID not available.');
      return;
    }

    setState(() => _saving = true);
    try {
      await _service.deleteStage(stage.id!);
      await _load();
      if (mounted) context.read<LeadProvider>().refreshStages();
      _showSnack('Stage deleted', success: true);
    } catch (e) {
      _showSnack(_friendlyError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _friendlyError(Object e) {
    final s = e.toString();
    if (s.contains('already exists')) return 'A stage with that name already exists.';
    if (s.contains('associated with leads')) {
      return 'Cannot delete: this stage still has leads assigned to it.';
    }
    return s;
  }

  Future<(String, String)?> _showAddStageDialog({
    String? preselectedPipeline,
  }) async {
    final nameCtrl = TextEditingController();
    String selectedPipeline =
        preselectedPipeline ?? LeadProvider.knownPipelines.first;

    return showDialog<(String, String)>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
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
                  'Add Stage',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '* Stage Name',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: 'Example: QUALIFIED',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppTheme.textTertiary,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
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
                      borderSide:
                          const BorderSide(color: AppTheme.primaryBlue, width: 2),
                    ),
                  ),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '* Pipeline',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(12),
                    color: const Color(0xFFF8FAFC),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedPipeline,
                      isExpanded: true,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      borderRadius: BorderRadius.circular(12),
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textPrimary,
                      ),
                      onChanged: (val) {
                        if (val != null) setDialog(() => selectedPipeline = val);
                      },
                      items: LeadProvider.knownPipelines
                          .map(
                            (p) => DropdownMenuItem(
                              value: p,
                              child: Text(p),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
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
                      onPressed: () =>
                          Navigator.pop(ctx, (nameCtrl.text, selectedPipeline)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                      ),
                      child: Text(
                        'OK',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700),
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

  Future<String?> _showNameDialog({
    String title = 'Add Stage',
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
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: 'Stage name (e.g. FIRST OUTREACH)',
                  hintStyle: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppTheme.textTertiary,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
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
                    borderSide:
                        const BorderSide(color: AppTheme.primaryBlue, width: 2),
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
                          horizontal: 20, vertical: 12),
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

  Future<bool> _showDeleteConfirm(String stageName) async {
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
                'Delete Stage',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Are you sure you want to delete "$stageName"?\nLeads in this stage will not be deleted.',
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
        backgroundColor:
            success ? const Color(0xFF10B981) : const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

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
          'Stage Pipeline',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          TextButton.icon(
            onPressed: _saving ? null : () => _addStage(),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(
              'Add Stage',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: TextButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFF3F4F6)),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppTheme.primaryBlue,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildStatsRow(),
                      const SizedBox(height: 20),
                      ..._buildPipelineSections(),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Total Stages',
            value: '$_totalStages',
            icon: Icons.layers_rounded,
            iconColor: const Color(0xFF3B82F6),
            bgColor: const Color(0xFFEFF6FF),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: 'Editable',
            value: '$_editableStages',
            icon: Icons.edit_rounded,
            iconColor: const Color(0xFFF59E0B),
            bgColor: const Color(0xFFFFFBEB),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: 'Pipelines',
            value: '$_pipelineCount',
            icon: Icons.account_tree_rounded,
            iconColor: const Color(0xFF8B5CF6),
            bgColor: const Color(0xFFF5F3FF),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildPipelineSections() {
    final widgets = <Widget>[];

    for (final pipeline in _pipelineStages.keys) {
      final stages = _pipelineStages[pipeline] ?? [];
      widgets.add(_buildPipelineCard(pipeline, stages));
      widgets.add(const SizedBox(height: 16));
    }

    return widgets;
  }

  Widget _buildPipelineCard(String pipeline, List<LeadStage> stages) {
    final pipelineColor = _pipelineColor(pipeline);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: pipelineColor.withValues(alpha: 0.25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pipeline header
          Container(
            decoration: BoxDecoration(
              color: pipelineColor.withValues(alpha: 0.06),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14.5),
              ),
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: pipelineColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    pipeline,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: pipelineColor,
                    ),
                  ),
                ),
                InkWell(
                  onTap: _saving
                      ? null
                      : () => _addStage(preselectedPipeline: pipeline),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: pipelineColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.add_rounded,
                      size: 16,
                      color: pipelineColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Stages list
          if (stages.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.layers_outlined,
                      size: 32,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No stages in this pipeline',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppTheme.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _saving
                          ? null
                          : () => _addStage(preselectedPipeline: pipeline),
                      child: Text(
                        '+ Add first stage',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: pipelineColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: stages.length,
              separatorBuilder: (context, _) => Divider(
                height: 1,
                color: Colors.grey.shade100,
                indent: 16,
                endIndent: 16,
              ),
              itemBuilder: (context, index) {
                final stage = stages[index];
                return _StageRow(
                  stage: stage,
                  pipelineColor: pipelineColor,
                  onEdit: stage.id != null
                      ? () => _renameStage(pipeline, index)
                      : null,
                  onDelete: stage.id != null
                      ? () => _deleteStage(pipeline, index)
                      : null,
                );
              },
            ),
        ],
      ),
    );
  }

  Color _pipelineColor(String pipeline) {
    final lower = pipeline.toLowerCase();
    if (lower.contains('inquiry')) return const Color(0xFF6B21A8); // purple
    if (lower.contains('order')) return const Color(0xFFD97706); // amber
    if (lower.contains('dispatch')) return const Color(0xFF1D4ED8); // blue
    // Cycle through colors for unknown pipelines
    final index = _pipelineStages.keys.toList().indexOf(pipeline);
    const colors = [
      Color(0xFF059669),
      Color(0xFFDC2626),
      Color(0xFF0891B2),
    ];
    return colors[index % colors.length];
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded,
              size: 48, color: Colors.red.shade300),
          const SizedBox(height: 12),
          Text(
            _error!,
            style: GoogleFonts.inter(color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _load,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

// ── Stat Card ─────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color bgColor;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 15, color: iconColor),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: iconColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stage Row ─────────────────────────────────────────────────────────────────

class _StageRow extends StatelessWidget {
  final LeadStage stage;
  final Color pipelineColor;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _StageRow({
    required this.stage,
    required this.pipelineColor,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isSystem = stage.id == null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Drag handle dots (decorative)
          Icon(
            Icons.drag_indicator_rounded,
            size: 18,
            color: Colors.grey.shade300,
          ),
          const SizedBox(width: 10),
          // Stage name column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      stage.stage,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: pipelineColor,
                      ),
                    ),
                    if (isSystem) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'System',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textTertiary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Order #${stage.order}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppTheme.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          // Actions
          if (onEdit != null)
            InkWell(
              onTap: onEdit,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  Icons.edit_outlined,
                  size: 17,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          const SizedBox(width: 4),
          if (onDelete != null)
            InkWell(
              onTap: onDelete,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                  ),
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  size: 17,
                  color: Color(0xFFEF4444),
                ),
              ),
            )
          else
            const SizedBox(width: 29),
        ],
      ),
    );
  }
}
