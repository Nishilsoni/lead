import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_theme.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../models/lead.dart';
import '../../providers/lead_provider.dart';
import '../widgets/stage_badge.dart';
import 'lead_form_screen.dart';

class LeadDetailScreen extends StatefulWidget {
  final Lead lead;
  const LeadDetailScreen({super.key, required this.lead});

  @override
  State<LeadDetailScreen> createState() => _LeadDetailScreenState();
}

class _LeadDetailScreenState extends State<LeadDetailScreen> {
  late Lead _lead;

  @override
  void initState() {
    super.initState();
    _lead = widget.lead;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildContactSection(),
                const SizedBox(height: 12),
                _buildBusinessSection(),
                const SizedBox(height: 12),
                _buildLeadDetailsSection(),
                if (_lead.products.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildProductsSection(),
                ],
                if (_lead.tags.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildTagsSection(),
                ],
                if (_lead.notes.isNotEmpty || _lead.requirements.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildNotesSection(),
                ],
                const SizedBox(height: 80),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      backgroundColor: Colors.white,
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.stageColor(_lead.stage),
                AppTheme.stageColor(_lead.stage).withValues(alpha: 0.7),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    _lead.displayName,
                    style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(20)),
                      child: Text(_lead.stage, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                    ),
                    const SizedBox(width: 10),
                    Icon(Icons.calendar_today_rounded, size: 14, color: Colors.white.withValues(alpha: 0.8)),
                    const SizedBox(width: 4),
                    Text(DateFormatter.short(_lead.since), style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withValues(alpha: 0.9))),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        IconButton(icon: const Icon(Icons.edit_rounded), onPressed: _editLead),
        IconButton(icon: const Icon(Icons.delete_rounded), onPressed: _deleteLead),
      ],
    );
  }

  Widget _buildContactSection() {
    return _sectionCard('Contact Information', Icons.person_rounded, [
      _detailRow('Contact Person', _lead.contactPerson, Icons.badge_rounded),
      if (_lead.business.mobile.isNotEmpty)
        _detailRow('Mobile', _lead.business.mobile, Icons.phone_rounded,
            onTap: () => _copy(_lead.business.mobile, 'Phone')),
      if (_lead.business.email.isNotEmpty)
        _detailRow('Email', _lead.business.email, Icons.email_rounded,
            onTap: () => _copy(_lead.business.email, 'Email')),
      if (_lead.business.designation.isNotEmpty)
        _detailRow('Designation', _lead.business.designation, Icons.work_rounded),
    ]);
  }

  Widget _buildBusinessSection() {
    return _sectionCard('Business Details', Icons.business_rounded, [
      if (_lead.business.business.isNotEmpty) _detailRow('Business', _lead.business.business, Icons.store_rounded),
      if (_lead.business.website.isNotEmpty) _detailRow('Website', _lead.business.website, Icons.language_rounded),
      if (_lead.business.fullAddress.isNotEmpty) _detailRow('Address', _lead.business.fullAddress, Icons.location_on_rounded),
      if (_lead.business.gstin.isNotEmpty) _detailRow('GSTIN', _lead.business.gstin, Icons.receipt_long_rounded),
    ]);
  }

  Widget _buildLeadDetailsSection() {
    return _sectionCard('Lead Details', Icons.leaderboard_rounded, [
      _detailRow('Stage', '', Icons.flag_rounded, trailing: StageBadge(stage: _lead.stage)),
      if (_lead.potential > 0) _detailRow('Potential', '₹${_lead.potential}', Icons.monetization_on_rounded),
      if (_lead.source != null) _detailRow('Source', _lead.source!.name, Icons.source_rounded),
      if (_lead.assignedUser != null) _detailRow('Assigned To', _lead.assignedUser!.name, Icons.person_outline_rounded),
      _detailRow('Enquiry Date', DateFormatter.full(_lead.since), Icons.event_rounded),
    ]);
  }

  Widget _buildProductsSection() {
    return _sectionCard('Products / Services', Icons.category_rounded, [
      Wrap(
        spacing: 8, runSpacing: 8,
        children: _lead.products.map((p) => Chip(
          label: Text(p.name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500)),
          backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.08),
          side: BorderSide(color: AppTheme.primaryBlue.withValues(alpha: 0.2)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        )).toList(),
      ),
    ]);
  }

  Widget _buildTagsSection() {
    return _sectionCard('Tags', Icons.label_rounded, [
      Wrap(
        spacing: 8, runSpacing: 8,
        children: _lead.tags.map((t) => Chip(
          label: Text(t, style: GoogleFonts.inter(fontSize: 13)),
          backgroundColor: const Color(0xFFF3F4F6),
          side: const BorderSide(color: Color(0xFFE5E7EB)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        )).toList(),
      ),
    ]);
  }

  Widget _buildNotesSection() {
    return _sectionCard('Notes & Requirements', Icons.note_rounded, [
      if (_lead.requirements.isNotEmpty) ...[
        Text('Requirements', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
        const SizedBox(height: 4),
        Text(_lead.requirements, style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textPrimary, height: 1.5)),
        if (_lead.notes.isNotEmpty) const SizedBox(height: 12),
      ],
      if (_lead.notes.isNotEmpty) ...[
        Text('Notes', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
        const SizedBox(height: 4),
        Text(_lead.notes, style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textPrimary, height: 1.5)),
      ],
    ]);
  }

  Widget _sectionCard(String title, IconData icon, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF000000).withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(children: [
            Icon(icon, size: 18, color: AppTheme.primaryBlue),
            const SizedBox(width: 8),
            Text(title, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          ]),
        ),
        const Divider(),
        Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children)),
      ]),
    );
  }

  Widget _detailRow(String label, String value, IconData icon, {VoidCallback? onTap, Widget? trailing}) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 18, color: AppTheme.textTertiary),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textTertiary, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          if (trailing != null) trailing else Text(value, style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textPrimary)),
        ])),
        if (onTap != null) Icon(Icons.copy_rounded, size: 16, color: AppTheme.textTertiary),
      ]),
    );
    return onTap != null ? InkWell(onTap: onTap, borderRadius: BorderRadius.circular(8), child: content) : content;
  }

  void _copy(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    if (mounted) SnackbarHelper.showInfo(context, '$label copied');
  }

  void _editLead() {
    final provider = context.read<LeadProvider>();
    Navigator.push(context, MaterialPageRoute(builder: (_) => LeadFormScreen(lead: _lead))).then((result) {
      if (result == true) {
        provider.getLeadById(_lead.id).then((updated) {
          if (mounted) setState(() => _lead = updated);
        });
      }
    });
  }

  void _deleteLead() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Lead', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        content: Text('Delete "${_lead.displayName}"? This cannot be undone.', style: GoogleFonts.inter(color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: GoogleFonts.inter(color: AppTheme.textSecondary))),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await context.read<LeadProvider>().deleteLead(_lead.id);
                if (mounted) { SnackbarHelper.showSuccess(context, 'Lead deleted'); Navigator.pop(context); }
              } catch (e) {
                if (mounted) SnackbarHelper.showError(context, e.toString());
              }
            },
            child: Text('Delete', style: GoogleFonts.inter(color: const Color(0xFFEF4444), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
