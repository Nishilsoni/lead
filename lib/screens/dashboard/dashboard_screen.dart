import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_theme.dart';
import '../../models/activity.dart';
import '../../models/dashboard_stats.dart';
import '../../services/activity_service.dart';
import '../../services/dashboard_service.dart';
import '../leads/lead_activities_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DashboardService _dashboardService = DashboardService();
  final ActivityService _activityService = ActivityService();

  late DashboardStats _stats;
  List<Appointment> _todayAppointments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      final results = await Future.wait([
        _dashboardService.getStats(),
        _activityService.getAppointments(
          since: DateTime(now.year, now.month, now.day),
          until: DateTime(now.year, now.month, now.day, 23, 59, 59),
        ),
      ]);
      if (mounted) {
        setState(() {
          _stats = results[0] as DashboardStats;
          _todayAppointments = results[1] as List<Appointment>;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded, color: AppTheme.textPrimary),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
        title: Text(
          'Dashboard',
          style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey.shade100, height: 1),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              color: AppTheme.primaryBlue,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                children: [
                  _buildGreeting(),
                  const SizedBox(height: 20),
                  _buildSectionLabel('Performance Metrics'),
                  const SizedBox(height: 10),
                  _buildKpiGrid(),
                  const SizedBox(height: 24),
                  _buildScheduleHeader(),
                  const SizedBox(height: 10),
                  _todayAppointments.isEmpty
                      ? _buildEmptySchedule()
                      : _buildAppointmentsList(),
                ],
              ),
            ),
    );
  }

  // ── Greeting ──────────────────────────────────────────────────────────────

  Widget _buildGreeting() {
    final now = DateTime.now();
    final hour = now.hour;
    final String greeting;
    final String emoji;
    if (hour < 12) {
      greeting = 'Good Morning';
      emoji = '☀️';
    } else if (hour < 17) {
      greeting = 'Good Afternoon';
      emoji = '👋';
    } else {
      greeting = 'Good Evening';
      emoji = '🌙';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryBlue,
            AppTheme.primaryBlue.withValues(alpha: 0.75),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryBlue.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$greeting $emoji',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('EEEE, MMMM d, yyyy').format(now),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  _todayAppointments.length.toString(),
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Today',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Section label ─────────────────────────────────────────────────────────

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppTheme.textPrimary,
        letterSpacing: 0.2,
      ),
    );
  }

  // ── KPI Grid ──────────────────────────────────────────────────────────────

  Widget _buildKpiGrid() {
    final cards = [
      _KpiCardData(title: 'Total Leads',     value: _stats.totalLeads.toString(),                   change: _stats.totalLeadsChange,     icon: Icons.people_alt_rounded,                color: const Color(0xFF4F6EF7)),
      _KpiCardData(title: 'Open Deals',      value: _stats.openDeals.toString(),                    change: _stats.openDealsChange,      icon: Icons.trending_up_rounded,               color: const Color(0xFFE07B39)),
      _KpiCardData(title: 'Won Deals',       value: _stats.wonDeals.toString(),                     change: _stats.wonDealsChange,       icon: Icons.check_circle_outline_rounded,       color: const Color(0xFF12B76A)),
      _KpiCardData(title: 'Pipeline',        value: _formatCurrency(_stats.pipelineValue),          change: _stats.pipelineValueChange,  icon: Icons.account_balance_wallet_outlined,   color: const Color(0xFF7C3AED)),
      _KpiCardData(title: 'Conversion',      value: '${_stats.conversionRate.toStringAsFixed(1)}%', change: _stats.conversionRateChange, icon: Icons.show_chart_rounded,                color: const Color(0xFFD63384)),
      _KpiCardData(title: 'Avg Deal',        value: _formatCurrency(_stats.avgDealSize),            change: _stats.avgDealSizeChange,    icon: Icons.bar_chart_rounded,                 color: const Color(0xFF0BA5D3)),
    ];

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.8,
      children: cards.map(_buildKpiCard).toList(),
    );
  }

  Widget _buildKpiCard(_KpiCardData d) {
    final isPositive = d.change >= 0;
    final changeColor = isPositive ? const Color(0xFF12B76A) : const Color(0xFFEF4444);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: d.color.withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Top accent stripe
            Positioned(
              top: 0, left: 0, right: 0,
              child: Container(
                height: 3,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [d.color, d.color.withValues(alpha: 0.3)],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [d.color, d.color.withValues(alpha: 0.68)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(9),
                          boxShadow: [
                            BoxShadow(
                              color: d.color.withValues(alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Icon(d.icon, color: Colors.white, size: 15),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: changeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isPositive ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                              size: 9,
                              color: changeColor,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '${d.change.abs().toStringAsFixed(0)}%',
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: changeColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    d.value,
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                      letterSpacing: -0.5,
                      height: 1.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    d.title,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Schedule ──────────────────────────────────────────────────────────────

  Widget _buildScheduleHeader() {
    return Row(
      children: [
        _buildSectionLabel("Today's Schedule"),
        const Spacer(),
        if (_todayAppointments.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_todayAppointments.length} ${_todayAppointments.length == 1 ? 'event' : 'events'}',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryBlue,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptySchedule() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.event_available_rounded, size: 40, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              'No events scheduled for today',
              style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentsList() {
    return Column(
      children: _todayAppointments
          .map((appt) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildAppointmentCard(appt),
              ))
          .toList(),
    );
  }

  Widget _buildAppointmentCard(Appointment appt) {
    final statusColor = appt.isCompleted
        ? const Color(0xFF12B76A)
        : appt.isCancelled
            ? const Color(0xFFEF4444)
            : AppTheme.primaryBlue;

    final statusLabel = appt.isCompleted ? 'Completed' : appt.isCancelled ? 'Cancelled' : 'Scheduled';

    final typeIcon = appt.appointmentType.toLowerCase().contains('meeting')
        ? Icons.groups_rounded
        : appt.appointmentType.toLowerCase().contains('email')
            ? Icons.email_rounded
            : Icons.phone_rounded;

    final timeStr = DateFormat('h:mm a').format(appt.scheduledAt.toLocal());

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LeadActivitiesScreen(
            leadId: appt.leadId,
            leadName: appt.business.name,
            assignedUserId: appt.assignedUser.id,
          ),
        ),
      ),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border(
            left: BorderSide(color: statusColor, width: 4),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Type icon circle
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(typeIcon, color: statusColor, size: 20),
              ),
              const SizedBox(width: 12),
              // Main info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            appt.business.name.isNotEmpty ? appt.business.name : 'Unknown',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Status badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            statusLabel,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    // Time + type row
                    Row(
                      children: [
                        Icon(Icons.access_time_rounded, size: 12, color: AppTheme.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          timeStr,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            appt.appointmentType,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (appt.assignedUser.name.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Icon(Icons.person_outline_rounded, size: 12, color: AppTheme.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            appt.assignedUser.name,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (appt.note.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Text(
                          appt.note,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppTheme.textPrimary,
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _formatCurrency(double value) {
    if (value >= 1000000) return '₹${(value / 1000000).toStringAsFixed(1)}L';
    if (value >= 100000) return '₹${(value / 100000).toStringAsFixed(1)}L';
    if (value >= 1000) return '₹${(value / 1000).toStringAsFixed(1)}K';
    return '₹${value.toStringAsFixed(0)}';
  }

}

// ── Data class ────────────────────────────────────────────────────────────────

class _KpiCardData {
  final String title;
  final String value;
  final double change;
  final IconData icon;
  final Color color;

  const _KpiCardData({
    required this.title,
    required this.value,
    required this.change,
    required this.icon,
    required this.color,
  });
}

