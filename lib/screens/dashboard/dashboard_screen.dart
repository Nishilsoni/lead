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
  int _todayAppointmentsCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

      final results = await Future.wait([
        _dashboardService.getStats(),
        _activityService.getAppointments(since: startOfDay, until: endOfDay),
      ]);
      final stats = results[0] as DashboardStats;
      final appointments = results[1] as List<Appointment>;

      if (mounted) {
        setState(() {
          _stats = stats;
          _todayAppointments = appointments;
          _todayAppointmentsCount = appointments.length;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load dashboard: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded, color: AppTheme.textPrimary),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
        title: Text(
          'Dashboard',
          style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── Date & Greeting ──
                  _buildDateGreeting(),
                  const SizedBox(height: 24),

                  // ── KPI Grid (2 columns x 3 rows) ──
                  Text(
                    'Performance Metrics',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildKpiGrid(),
                  const SizedBox(height: 32),

                  // ── Today's Appointments ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Today\'s Schedule',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _todayAppointmentsCount.toString(),
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _todayAppointments.isEmpty
                      ? _buildEmptyAppointments()
                      : _buildAppointmentsList(),
                ],
              ),
            ),
    );
  }

  Widget _buildDateGreeting() {
    final now = DateTime.now();
    final greeting = _getGreeting();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          greeting,
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          DateFormat('EEEE, MMMM d, yyyy').format(now),
          style: GoogleFonts.inter(
            fontSize: 14,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning! ☀️';
    } else if (hour < 17) {
      return 'Good Afternoon! 👋';
    } else {
      return 'Good Evening! 🌙';
    }
  }

  Widget _buildKpiGrid() {
    return Column(
      children: [
        // Row 1: Total Leads, Open Deals
        Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                title: 'Total Leads',
                value: _stats.totalLeads.toString(),
                change: _stats.totalLeadsChange,
                icon: Icons.people_alt_rounded,
                color: const Color(0xFF3B5BCC),
                backgroundColor: const Color(0xFFE8EDFF), // Rich periwinkle
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildKpiCard(
                title: 'Open Deals',
                value: _stats.openDeals.toString(),
                change: _stats.openDealsChange,
                icon: Icons.trending_up_rounded,
                color: const Color(0xFFC89456),
                backgroundColor: const Color(0xFFFEF3E6), // Rich cream
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Row 2: Won Deals, Pipeline Value
        Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                title: 'Won Deals',
                value: _stats.wonDeals.toString(),
                change: _stats.wonDealsChange,
                icon: Icons.check_circle_rounded,
                color: const Color(0xFF16A34A),
                backgroundColor: const Color(0xFFDCF8E8), // Rich mint
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildKpiCard(
                title: 'Pipeline Value',
                value: _formatCurrency(_stats.pipelineValue),
                change: _stats.pipelineValueChange,
                icon: Icons.wallet_rounded,
                color: const Color(0xFF7C3AED),
                backgroundColor: const Color(0xFFEDD5FF), // Rich purple
                isCurrency: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Row 3: Conversion Rate, Avg Deal Size
        Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                title: 'Conversion Rate',
                value: '${_stats.conversionRate.toStringAsFixed(1)}%',
                change: _stats.conversionRateChange,
                icon: Icons.show_chart_rounded,
                color: const Color(0xFFBE185D),
                backgroundColor: const Color(0xFFFCE7F0), // Rich pink
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildKpiCard(
                title: 'Avg Deal Size',
                value: _formatCurrency(_stats.avgDealSize),
                change: _stats.avgDealSizeChange,
                icon: Icons.assessment_rounded,
                color: const Color(0xFF0891B2),
                backgroundColor: const Color(0xFFCCFAFF), // Rich cyan
                isCurrency: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required double change,
    required IconData icon,
    required Color color,
    required Color backgroundColor,
    bool isCurrency = false,
  }) {
    final isPositive = change >= 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
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
          // Icon & Title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              // Change indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isPositive
                      ? const Color(0xFF10B981).withValues(alpha: 0.1)
                      : const Color(0xFFEF4444).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPositive ? Icons.trending_up : Icons.trending_down,
                      size: 12,
                      color: isPositive
                          ? const Color(0xFF10B981)
                          : const Color(0xFFEF4444),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${change.abs().toStringAsFixed(0)}%',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isPositive
                            ? const Color(0xFF10B981)
                            : const Color(0xFFEF4444),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Title
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          // Value
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          // Comparison text
          Text(
            'vs last 30 days',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: AppTheme.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  String _formatCurrency(double value) {
    if (value >= 1000000) {
      return '₹${(value / 1000000).toStringAsFixed(1)}L';
    } else if (value >= 100000) {
      return '₹${(value / 100000).toStringAsFixed(1)}L';
    } else if (value >= 1000) {
      return '₹${(value / 1000).toStringAsFixed(1)}K';
    }
    return '₹${value.toStringAsFixed(0)}';
  }

  Widget _buildEmptyAppointments() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6), width: 1),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.event_available_rounded,
              size: 48,
              color: AppTheme.textTertiary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No appointments scheduled for today.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentsList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _todayAppointments.length,
      itemBuilder: (context, index) {
        final appt = _todayAppointments[index];
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
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF3F4F6), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Icon(
                      appt.appointmentType == 'Meeting'
                          ? Icons.groups_rounded
                          : Icons.phone_rounded,
                      color: AppTheme.primaryBlue,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appt.appointmentType,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('h:mm a').format(appt.scheduledAt.toLocal()),
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      if (appt.note.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          appt.note,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppTheme.textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                _buildStatusBadge(appt.status),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    IconData icon;
    switch (status) {
      case 'COMPLETED':
        color = const Color(0xFF10B981);
        icon = Icons.check_circle_rounded;
        break;
      case 'CANCELLED':
        color = const Color(0xFFEF4444);
        icon = Icons.cancel_rounded;
        break;
      default:
        color = const Color(0xFF3B82F6);
        icon = Icons.schedule_rounded;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(icon, size: 16, color: color),
    );
  }
}
