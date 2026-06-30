import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_theme.dart';
import '../../models/meta_account.dart';
import '../../services/meta_service.dart';
import '../widgets/notification_bell.dart';

const Color _fbBlue = Color(0xFF1877F2);

/// Marketing Management — pick a connected ad account and view its campaign
/// performance (account-level insight cards + per-campaign list).
class MarketingManagementScreen extends StatefulWidget {
  const MarketingManagementScreen({super.key});

  @override
  State<MarketingManagementScreen> createState() =>
      _MarketingManagementScreenState();
}

class _MarketingManagementScreenState extends State<MarketingManagementScreen> {
  final MetaService _service = MetaService();

  List<MetaAdAccount> _accounts = [];
  MetaAdAccount? _selected;
  CampaignListResult? _result;

  bool _loadingAccounts = true;
  bool _loadingCampaigns = false;
  String? _accountsError;
  String? _campaignsError;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    setState(() {
      _loadingAccounts = true;
      _accountsError = null;
    });
    try {
      final accounts = await _service.getAdAccounts();
      if (!mounted) return;
      setState(() {
        _accounts = accounts;
        _selected = accounts.isNotEmpty ? accounts.first : null;
        _loadingAccounts = false;
      });
      if (_selected != null) _loadCampaigns();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _accountsError = e.toString();
        _loadingAccounts = false;
      });
    }
  }

  Future<void> _loadCampaigns() async {
    final account = _selected;
    if (account == null) return;
    setState(() {
      _loadingCampaigns = true;
      _campaignsError = null;
    });
    try {
      final result = await _service.getCampaigns(account.accountId);
      if (!mounted) return;
      setState(() {
        _result = result;
        _loadingCampaigns = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _campaignsError = e.toString();
        _loadingCampaigns = false;
      });
    }
  }

  void _selectAccount(MetaAdAccount account) {
    if (account.accountId == _selected?.accountId) return;
    setState(() {
      _selected = account;
      _result = null;
    });
    _loadCampaigns();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Marketing',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        actions: [
          if (_selected != null)
            IconButton(
              icon: _loadingCampaigns
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded,
                      color: AppTheme.textSecondary),
              onPressed: _loadingCampaigns ? null : _loadCampaigns,
            ),
          const NotificationBell(),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFF1F5F9)),
        ),
      ),
      body: _loadingAccounts
          ? const Center(child: CircularProgressIndicator())
          : _accountsError != null
              ? _buildError(_accountsError!, _loadAccounts)
              : _accounts.isEmpty
                  ? _buildNoAccounts()
                  : _buildContent(),
    );
  }

  Widget _buildContent() {
    return RefreshIndicator(
      onRefresh: _loadCampaigns,
      color: _fbBlue,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildAccountSelector(),
          const SizedBox(height: 16),
          _buildStatsGrid(),
          const SizedBox(height: 16),
          _buildCampaignsSection(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── Account selector ───────────────────────────────────────────────

  Widget _buildAccountSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: _fbBlue,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.facebook_rounded,
                    size: 14, color: Colors.white),
                const SizedBox(width: 4),
                Text(
                  'Connected',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _selected?.accountId,
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
                borderRadius: BorderRadius.circular(12),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
                items: _accounts
                    .map(
                      (a) => DropdownMenuItem(
                        value: a.accountId,
                        child: Text(
                          a.accountName,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (id) {
                  final account =
                      _accounts.firstWhere((a) => a.accountId == id);
                  _selectAccount(account);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Stat cards ─────────────────────────────────────────────────────

  Widget _buildStatsGrid() {
    final summary = _result?.summary;
    final loading = _loadingCampaigns && _result == null;

    return Row(
      children: [
        Expanded(
          child: _statCard(
            label: 'Impressions',
            value: loading ? '—' : _compact(summary?.totalImpressions ?? 0),
            accent: const Color(0xFF3B82F6),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard(
            label: 'Clicks',
            value: loading ? '—' : _compact(summary?.totalClicks ?? 0),
            accent: const Color(0xFFEF4444),
          ),
        ),
      ],
    );
  }

  Widget _buildSecondStatsRow() {
    final summary = _result?.summary;
    final currency = summary?.currency.isNotEmpty == true
        ? summary!.currency
        : _selected?.currency ?? '';
    final loading = _loadingCampaigns && _result == null;
    return Row(
      children: [
        Expanded(
          child: _statCard(
            label: 'Click-Through Rate',
            value: loading
                ? '—'
                : '${(summary?.ctr ?? 0).toStringAsFixed(2)} %',
            accent: const Color(0xFF10B981),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard(
            label: 'Total Spend',
            value: loading
                ? '—'
                : '${currency.isNotEmpty ? '$currency ' : ''}'
                    '${(summary?.totalSpend ?? 0).toStringAsFixed(2)}',
            accent: const Color(0xFFF59E0B),
          ),
        ),
      ],
    );
  }

  Widget _statCard({
    required String label,
    required String value,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 12, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 3,
                height: 22,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: accent,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Campaigns ──────────────────────────────────────────────────────

  Widget _buildCampaignsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSecondStatsRow(),
        const SizedBox(height: 20),
        Text(
          'CAMPAIGNS',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppTheme.textSecondary,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 12),
        if (_loadingCampaigns && _result == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_campaignsError != null)
          _buildError(_campaignsError!, _loadCampaigns)
        else if ((_result?.campaigns ?? []).isEmpty)
          _buildNoCampaigns()
        else
          ..._result!.campaigns.map(_buildCampaignCard),
      ],
    );
  }

  Widget _buildCampaignCard(MetaCampaign campaign) {
    final currency = _result?.summary.currency.isNotEmpty == true
        ? _result!.summary.currency
        : _selected?.currency ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  campaign.campaignName,
                  style: GoogleFonts.inter(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              if (campaign.status.isNotEmpty) _statusChip(campaign.status),
            ],
          ),
          if (campaign.startTime != null || campaign.endTime != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.calendar_today_rounded,
                    size: 12, color: AppTheme.textTertiary),
                const SizedBox(width: 5),
                Text(
                  _dateRange(campaign),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              _metric('Impressions', _compact(campaign.insights.impressions)),
              _metric('Clicks', _compact(campaign.insights.clicks)),
              _metric('CTR', '${campaign.insights.ctr.toStringAsFixed(2)}%'),
              _metric(
                'Spend',
                '${currency.isNotEmpty ? '$currency ' : ''}'
                    '${campaign.insights.spend.toStringAsFixed(2)}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: AppTheme.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    final isActive = status.toUpperCase().contains('ACTIVE');
    final color =
        isActive ? const Color(0xFF10B981) : AppTheme.textTertiary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  // ── Empty / error states ───────────────────────────────────────────

  Widget _buildNoCampaigns() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.inbox_rounded, size: 44, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            'No campaigns found for this ad account',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoAccounts() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: _fbBlue.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(Icons.campaign_rounded, color: _fbBlue, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              'No ad accounts connected',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Connect a Facebook ad account from the web application to see '
              'campaign performance here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(String message, VoidCallback onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 48, color: Colors.red.shade300),
            const SizedBox(height: 12),
            Text(
              message,
              style: GoogleFonts.inter(color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────

  String _compact(int n) {
    return NumberFormat.compact().format(n);
  }

  /// "08/06/2026 → —" style range for a campaign's start/end dates.
  String _dateRange(MetaCampaign c) {
    final fmt = DateFormat('dd/MM/yyyy');
    final start =
        c.startTime != null ? fmt.format(c.startTime!.toLocal()) : '—';
    final end = c.endTime != null ? fmt.format(c.endTime!.toLocal()) : '—';
    return '$start → $end';
  }
}
