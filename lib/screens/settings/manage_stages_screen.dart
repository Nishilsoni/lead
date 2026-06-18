import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_theme.dart';
import '../../models/lead.dart';
import '../../providers/lead_provider.dart';
import '../../services/lead_service.dart';

class ManageStagesScreen extends StatefulWidget {
  const ManageStagesScreen({super.key});

  @override
  State<ManageStagesScreen> createState() => _ManageStagesScreenState();
}

class _ManageStagesScreenState extends State<ManageStagesScreen> {
  final LeadService _service = LeadService();
  List<LeadStage> _stages = [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final stages = await _service.getLeadStages();
      setState(() { _stages = List.from(stages); _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _addStage() async {
    final name = await _showNameDialog();
    if (name == null || name.trim().isEmpty) return;

    final nextOrder = _stages.isEmpty ? 1 : _stages.last.order + 1;
    setState(() => _saving = true);
    try {
      final created = await _service.createStage(
        name: name.trim().toUpperCase(),
        order: nextOrder,
      );
      final fresh = await _service.getLeadStages();
      setState(() => _stages = List.from(fresh));
      if (!fresh.any((s) => s.stage == created.stage)) {
        setState(() => _stages.add(created));
      }
      if (mounted) context.read<LeadProvider>().clearCache();
      _showSnack('Stage added', success: true);
    } catch (e) {
      _showSnack(_friendlyError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteStage(int index) async {
    final stage = _stages[index];
    final confirmed = await _showDeleteConfirm(stage.stage);
    if (!confirmed) return;

    if (stage.id == null) {
      _showSnack('Cannot delete: stage ID not available. Please refresh and try again.');
      return;
    }

    setState(() { _saving = true; _stages.removeAt(index); });
    try {
      await _service.deleteStage(stage.id!);
      if (mounted) context.read<LeadProvider>().clearCache();
      _showSnack('Stage deleted', success: true);
    } catch (e) {
      setState(() => _stages.insert(index, stage));
      _showSnack(_friendlyError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _friendlyError(Object e) {
    final s = e.toString();
    if (s.contains('already exists')) return 'A stage with that name already exists.';
    if (s.contains('integer')) return 'Cannot modify this stage. Please refresh.';
    return s;
  }

  Future<String?> _showNameDialog() {
    final ctrl = TextEditingController();
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
              Text('Add Stage',
                  style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary)),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: 'Stage name (e.g. FIRST OUTREACH)',
                  hintStyle: GoogleFonts.inter(
                      fontSize: 14, color: AppTheme.textTertiary),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                        BorderSide(color: AppTheme.primaryBlue, width: 2),
                  ),
                ),
                style: GoogleFonts.inter(
                    fontSize: 14, fontWeight: FontWeight.w600),
                onSubmitted: (v) => Navigator.pop(ctx, v),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('Cancel',
                        style: GoogleFonts.inter(
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, ctrl.text),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                    ),
                    child: Text('Add',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
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
                child: const Icon(Icons.delete_outline_rounded,
                    color: Color(0xFFEF4444), size: 28),
              ),
              const SizedBox(height: 16),
              Text('Delete Stage',
                  style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary)),
              const SizedBox(height: 8),
              Text(
                'Are you sure you want to delete "$stageName"?\nLeads in this stage will not be deleted.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 14, color: AppTheme.textSecondary),
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
                      child: Text('Cancel',
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary)),
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
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text('Delete',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.inter(fontSize: 13)),
      backgroundColor:
          success ? const Color(0xFF10B981) : const Color(0xFFEF4444),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
    ));
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
          'Manage Stages',
          style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary),
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
              : _buildBody(),
      floatingActionButton: _loading
          ? null
          : FloatingActionButton.extended(
              onPressed: _saving ? null : _addStage,
              backgroundColor: AppTheme.primaryBlue,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: Text('Add Stage',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600, color: Colors.white)),
            ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded,
              size: 48, color: Colors.red.shade300),
          const SizedBox(height: 12),
          Text(_error!,
              style: GoogleFonts.inter(color: AppTheme.textSecondary),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _load, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PIPELINE STAGES',
                style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textSecondary,
                    letterSpacing: 1.2),
              ),
              const SizedBox(height: 4),
              Text(
                'Swipe left to delete a stage',
                style: GoogleFonts.inter(
                    fontSize: 12, color: AppTheme.textTertiary),
              ),
            ],
          ),
        ),
        Expanded(
          child: _stages.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppTheme.primaryBlue,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                    itemCount: _stages.length,
                    itemBuilder: (context, index) {
                      final stage = _stages[index];
                      return _StageCard(
                        key: ValueKey(stage.stage),
                        stage: stage,
                        onDelete: stage.id != null
                            ? () => _deleteStage(index)
                            : null,
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.layers_outlined,
                size: 36, color: AppTheme.primaryBlue),
          ),
          const SizedBox(height: 16),
          Text('No stages yet',
              style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 6),
          Text('Tap "Add Stage" to create your first pipeline stage',
              style: GoogleFonts.inter(
                  fontSize: 13, color: AppTheme.textSecondary),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ── Stage Card ────────────────────────────────────────────────────────────────

class _StageCard extends StatelessWidget {
  final LeadStage stage;
  final VoidCallback? onDelete;

  const _StageCard({
    super.key,
    required this.stage,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.stageColor(stage.stage);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: onDelete != null
          ? Dismissible(
              key: ValueKey('d_${stage.stage}'),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 24),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.delete_outline_rounded,
                        color: Colors.white, size: 22),
                    SizedBox(height: 4),
                    Text('Delete',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              confirmDismiss: (_) async {
                onDelete!();
                return false;
              },
              child: _card(color),
            )
          : _card(color),
    );
  }

  Widget _card(Color color) {
    return Container(
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  '${stage.order}',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                stage.stage,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ),
            if (onDelete == null)
              Tooltip(
                message: 'Cannot delete: ID not available',
                child: Icon(Icons.lock_outline_rounded,
                    size: 16, color: Colors.grey.shade400),
              ),
          ],
        ),
      ),
    );
  }
}
