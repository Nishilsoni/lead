import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_theme.dart';
import '../../models/activity.dart';
import '../../services/activity_service.dart';
import '../../services/dashboard_service.dart';
import '../../services/notification_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DashboardService _dashboardService = DashboardService();
  final ActivityService _activityService = ActivityService();

  int _totalLeads = 0;
  List<Appointment> _todayAppointments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final leadCount = await _dashboardService.getLeadCount();
      
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);
      
      final appointments = await _activityService.getAppointments(
        since: startOfDay,
        until: endOfDay,
      );

      // Schedule notifications for upcoming appointments in the next 7 days
      final upcomingAppointments = await _activityService.getAppointments(
        since: now,
        until: now.add(const Duration(days: 7)),
      );
      print('[Dashboard] Found ${upcomingAppointments.length} upcoming appointments');
      for (var appt in upcomingAppointments) {
        print('[Dashboard] Appt: ${appt.note} at ${appt.scheduledAt}, status: ${appt.status}');
      }
      await NotificationService.scheduleAllUpcoming(upcomingAppointments);
      print('[Dashboard] Scheduled notifications for ${upcomingAppointments.length} appointments');

      if (mounted) {
        setState(() {
          _totalLeads = leadCount;
          _todayAppointments = appointments;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load dashboard data: $e')),
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
        title: Text(
          'Dashboard',
          style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSummaryCard(),
                  const SizedBox(height: 24),
                  Text(
                    'Today\'s Appointments',
                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
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

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryBlue, const Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryBlue.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.people_alt_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Leads',
                      style: GoogleFonts.inter(fontSize: 14, color: Colors.white.withValues(alpha: 0.9)),
                    ),
                    Text(
                      _totalLeads.toString(),
                      style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyAppointments() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6), width: 1.5),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.event_available_rounded, size: 48, color: AppTheme.textTertiary.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              'No appointments for today.',
              style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textSecondary),
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
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF3F4F6), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
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
                    appt.appointmentType == 'Meeting' ? Icons.groups_rounded : Icons.phone_rounded,
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
                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('h:mm a').format(appt.scheduledAt.toLocal()),
                      style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary),
                    ),
                    if (appt.note.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        appt.note,
                        style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textPrimary),
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
        );
      },
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status) {
      case 'COMPLETED':
        color = const Color(0xFF10B981);
        break;
      case 'CANCELLED':
        color = const Color(0xFFEF4444);
        break;
      default:
        color = const Color(0xFF3B82F6);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        status,
        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}
