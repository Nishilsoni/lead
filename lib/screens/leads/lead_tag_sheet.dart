import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_theme.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../models/lead.dart';
import '../../providers/lead_provider.dart';
import '../../providers/tag_provider.dart';

/// Bottom sheet for adding/removing tags on a single lead — opened from the
/// lead card's quick-actions menu ("Manage Tags"). Selection is local until
/// "Save Changes" is tapped, which persists it via
/// [LeadProvider.updateLeadTags] (a real PUT /v1/lead/{id} call).
class LeadTagSheet extends StatefulWidget {
  final Lead lead;
  const LeadTagSheet({super.key, required this.lead});

  static Future<void> show(BuildContext context, Lead lead) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => LeadTagSheet(lead: lead),
    );
  }

  @override
  State<LeadTagSheet> createState() => _LeadTagSheetState();
}

class _LeadTagSheetState extends State<LeadTagSheet> {
  final _searchCtrl = TextEditingController();
  late Set<String> _selected;
  String _query = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selected = {...widget.lead.tags};
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TagProvider>().loadTags();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Prompt for a new tag, create it as a real org tag, and select it.
  Future<void> _addTagInline() async {
    final tagProvider = context.read<TagProvider>();
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'New Tag',
          style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Tag name'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: AppTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty) return;

    setState(() => _selected.add(trimmed));
    // Persist it as a real org tag so it appears in the manager and filters.
    await tagProvider.ensureTag(trimmed);
  }

  Future<void> _save() async {
    if (setEquals(_selected, widget.lead.tags)) {
      Navigator.pop(context);
      return;
    }
    setState(() => _saving = true);
    try {
      final provider = context.read<LeadProvider>();
      final updated = await provider.updateLeadTags(widget.lead, _selected);
      if (updated == null) throw Exception('Could not update tags');
      if (!mounted) return;
      Navigator.pop(context);
      SnackbarHelper.showSuccess(context, 'Tags updated');
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      SnackbarHelper.showError(context, 'Could not update tags');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TagProvider>(
      builder: (context, tagProvider, _) {
        // Show every org tag plus any tag already on the lead that isn't yet
        // in the loaded list (e.g. a legacy free-text tag).
        final names = <String>{...tagProvider.tagNames, ..._selected}.toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        final filtered = _query.isEmpty
            ? names
            : names
                .where((n) => n.toLowerCase().contains(_query.toLowerCase()))
                .toList();

        return FractionallySizedBox(
          heightFactor: 0.85,
          child: Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom),
            child: SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: AppTheme.accentCyan.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.sell_rounded,
                              size: 18, color: AppTheme.accentCyan),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Manage Tags',
                                style: GoogleFonts.inter(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              Text(
                                widget.lead.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _addTagInline,
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: Text(
                            'New',
                            style: GoogleFonts.inter(
                                fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.primaryBlue,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() => _query = v),
                      style: GoogleFonts.inter(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Search tags...',
                        hintStyle:
                            GoogleFonts.inter(color: AppTheme.textTertiary),
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.close_rounded,
                                    size: 18, color: AppTheme.textTertiary),
                                onPressed: () => setState(() {
                                  _searchCtrl.clear();
                                  _query = '';
                                }),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: tagProvider.isLoading && names.isEmpty
                        ? const Center(child: CircularProgressIndicator())
                        : filtered.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(32),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 56,
                                        height: 56,
                                        decoration: BoxDecoration(
                                          color: AppTheme.surfaceGrey,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                            Icons.search_off_rounded,
                                            size: 26,
                                            color: AppTheme.textTertiary),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        names.isEmpty
                                            ? 'No tags yet. Tap "New" to create one.'
                                            : 'No matching tags',
                                        style: GoogleFonts.inter(
                                            color: AppTheme.textTertiary),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : ListView.separated(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 4, 16, 12),
                                itemCount: filtered.length,
                                separatorBuilder: (context, index) =>
                                    const SizedBox(height: 4),
                                itemBuilder: (context, i) {
                                  final name = filtered[i];
                                  final sel = _selected.contains(name);
                                  return _pickerRow(
                                    name: name,
                                    selected: sel,
                                    onTap: () => setState(() {
                                      if (sel) {
                                        _selected.remove(name);
                                      } else {
                                        _selected.add(name);
                                      }
                                    }),
                                  );
                                },
                              ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: Colors.grey.shade100)),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _selected.isEmpty
                                    ? 'Save (no tags)'
                                    : 'Save Changes (${_selected.length})',
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _pickerRow({
    required String name,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primaryBlue.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? AppTheme.primaryBlue.withValues(alpha: 0.3)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color:
                      selected ? AppTheme.primaryBlue : AppTheme.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 10),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? AppTheme.primaryBlue : Colors.transparent,
                border: Border.all(
                  color: selected
                      ? AppTheme.primaryBlue
                      : const Color(0xFFD1D5DB),
                  width: 1.5,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check_rounded,
                      size: 15, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
