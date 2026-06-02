import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_theme.dart';
import '../../models/activity.dart';
import '../../services/activity_service.dart';
import '../widgets/empty_state.dart';
import 'add_activity_sheet.dart';
import 'add_appointment_sheet.dart';

class LeadActivitiesScreen extends StatefulWidget {
  final String leadId;
  final String leadName;
  final String assignedUserId;

  const LeadActivitiesScreen({
    super.key,
    required this.leadId,
    required this.leadName,
    required this.assignedUserId,
  });

  @override
  State<LeadActivitiesScreen> createState() => _LeadActivitiesScreenState();
}

class _LeadActivitiesScreenState extends State<LeadActivitiesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ActivityService _service = ActivityService();

  List<Interaction> _interactions = [];
  List<Appointment> _appointments = [];
  bool _loadingInteractions = true;
  bool _loadingAppointments = true;
  String? _interactionError;
  String? _appointmentError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadInteractions();
    _loadAppointments();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInteractions() async {
    setState(() { _loadingInteractions = true; _interactionError = null; });
    try {
      final data = await _service.getInteractions(leadId: widget.leadId);
      if (mounted) setState(() { _interactions = data; _loadingInteractions = false; });
    } catch (e) {
      if (mounted) setState(() { _interactionError = e.toString(); _loadingInteractions = false; });
    }
  }

  Future<void> _loadAppointments() async {
    setState(() { _loadingAppointments = true; _appointmentError = null; });
    try {
      final data = await _service.getAppointments(leadId: widget.leadId);
      if (mounted) setState(() { _appointments = data; _loadingAppointments = false; });
    } catch (e) {
      if (mounted) setState(() { _appointmentError = e.toString(); _loadingAppointments = false; });
    }
  }

  Future<void> _updateAppointmentStatus(Appointment appt, String status, String note) async {
    try {
      await _service.updateAppointmentStatus(
        appointmentId: appt.id,
        status: status,
        note: note,
        appointmentType: appt.appointmentType,
        scheduledAt: appt.scheduledAt,
        assignedTo: appt.assignedUser.id,
      );
      _loadAppointments();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Activities', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            Text(widget.leadName, style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary)),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
          unselectedLabelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
          labelColor: AppTheme.primaryBlue,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primaryBlue,
          indicatorWeight: 2.5,
          tabs: [
            Tab(text: 'Interactions (${_interactions.length})'),
            Tab(text: 'Appointments (${_appointments.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildInteractionsTab(),
          _buildAppointmentsTab(),
        ],
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _tabController,
        builder: (context, child) {
          final isInteraction = _tabController.index == 0;
          return FloatingActionButton.extended(
            onPressed: isInteraction ? _addInteraction : _addAppointment,
            icon: const Icon(Icons.add_rounded),
            label: Text(
              isInteraction ? 'Log Activity' : 'Schedule',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInteractionsTab() {
    if (_loadingInteractions) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_interactionError != null) {
      return EmptyState(
        title: 'Failed to load',
        subtitle: _interactionError!,
        icon: Icons.error_outline_rounded,
        actionLabel: 'Retry',
        onAction: _loadInteractions,
      );
    }
    if (_interactions.isEmpty) {
      return EmptyState(
        title: 'No activities yet',
        subtitle: 'Log your first interaction with this lead',
        icon: Icons.history_rounded,
        actionLabel: 'Log Activity',
        onAction: _addInteraction,
      );
    }
    return RefreshIndicator(
      onRefresh: _loadInteractions,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount: _interactions.length,
        itemBuilder: (_, i) => _InteractionCard(interaction: _interactions[i]),
      ),
    );
  }

  Widget _buildAppointmentsTab() {
    if (_loadingAppointments) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_appointmentError != null) {
      return EmptyState(
        title: 'Failed to load',
        subtitle: _appointmentError!,
        icon: Icons.error_outline_rounded,
        actionLabel: 'Retry',
        onAction: _loadAppointments,
      );
    }
    if (_appointments.isEmpty) {
      return EmptyState(
        title: 'No appointments yet',
        subtitle: 'Schedule your first appointment for this lead',
        icon: Icons.event_rounded,
        actionLabel: 'Schedule',
        onAction: _addAppointment,
      );
    }
    return RefreshIndicator(
      onRefresh: _loadAppointments,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount: _appointments.length,
        itemBuilder: (_, i) => _AppointmentCard(
          appointment: _appointments[i],
          onStatusChange: _updateAppointmentStatus,
        ),
      ),
    );
  }

  void _addInteraction() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddActivitySheet(leadId: widget.leadId),
    );
    if (result == true) _loadInteractions();
  }

  void _addAppointment() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddAppointmentSheet(
        leadId: widget.leadId,
        assignedUserId: widget.assignedUserId,
      ),
    );
    if (result == true) _loadAppointments();
  }
}

// ── Interaction Card ──────────────────────────────────────────────────────────

class _InteractionCard extends StatelessWidget {
  final Interaction interaction;
  const _InteractionCard({required this.interaction});

  @override
  Widget build(BuildContext context) {
    final color = _typeColor(interaction.interactionType);
    final icon = _typeIcon(interaction.interactionType);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6), width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(interaction.interactionType,
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
                      ),
                      const Spacer(),
                      Text(
                        DateFormat('MMM d, h:mm a').format(interaction.interactedAt.toLocal()),
                        style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textTertiary),
                      ),
                    ],
                  ),
                  if (interaction.note.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(interaction.note,
                      style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textPrimary, height: 1.4)),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.person_outline_rounded, size: 13, color: AppTheme.textTertiary),
                      const SizedBox(width: 4),
                      Text(interaction.interactedByUser.name,
                        style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textTertiary)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'Call': return const Color(0xFF10B981);
      case 'Meeting': return const Color(0xFF3B82F6);
      case 'Online': return const Color(0xFF8B5CF6);
      case 'Email': return const Color(0xFFF59E0B);
      case 'Message': return const Color(0xFF06B6D4);
      default: return const Color(0xFF6B7280);
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'Call': return Icons.phone_rounded;
      case 'Meeting': return Icons.groups_rounded;
      case 'Online': return Icons.videocam_rounded;
      case 'Email': return Icons.email_rounded;
      case 'Message': return Icons.chat_bubble_rounded;
      default: return Icons.notes_rounded;
    }
  }
}

// ── Appointment Card ──────────────────────────────────────────────────────────

class _AppointmentCard extends StatelessWidget {
  final Appointment appointment;
  final void Function(Appointment, String, String) onStatusChange;

  const _AppointmentCard({required this.appointment, required this.onStatusChange});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(appointment.status);
    final icon = _typeIcon(appointment.appointmentType);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6), width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(appointment.appointmentType,
                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
                          ),
                          const SizedBox(width: 8),
                          _StatusBadge(status: appointment.status),
                          const Spacer(),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.schedule_rounded, size: 14, color: AppTheme.textTertiary),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('MMM d, yyyy · h:mm a').format(appointment.scheduledAt.toLocal()),
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                          ),
                        ],
                      ),
                      if (appointment.note.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(appointment.note,
                          style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary, height: 1.4)),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.person_outline_rounded, size: 13, color: AppTheme.textTertiary),
                          const SizedBox(width: 4),
                          Text(appointment.assignedUser.name,
                            style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textTertiary)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (appointment.isScheduled) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () async {
                        final note = await _showStatusDialog(context, 'COMPLETED');
                        if (note != null) {
                          onStatusChange(appointment, 'COMPLETED', note);
                        }
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF10B981),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.08),
                      ),
                      child: Text('Mark Done', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextButton(
                      onPressed: () async {
                        final note = await _showStatusDialog(context, 'CANCELLED');
                        if (note != null) {
                          onStatusChange(appointment, 'CANCELLED', note);
                        }
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFEF4444),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.08),
                      ),
                      child: Text('Cancel', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<String?> _showStatusDialog(BuildContext context, String status) async {
    final noteController = TextEditingController();
    final isDone = status == 'COMPLETED';
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Text(
          isDone ? 'Complete Appointment' : 'Cancel Appointment',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add a note before closing this appointment.',
              style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: noteController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Enter note here...',
                hintStyle: GoogleFonts.inter(color: AppTheme.textTertiary, fontSize: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.primaryBlue, width: 2),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Back', style: GoogleFonts.inter(color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, noteController.text.trim());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isDone ? const Color(0xFF10B981) : const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Submit', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    return result?.trim();
  }


  

  Color _statusColor(String status) {
    switch (status) {
      case 'COMPLETED': return const Color(0xFF10B981);
      case 'CANCELLED': return const Color(0xFFEF4444);
      default: return const Color(0xFF3B82F6);
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'Call': return Icons.phone_rounded;
      case 'Meeting': return Icons.groups_rounded;
      case 'Online': return Icons.videocam_rounded;
      case 'Email': return Icons.email_rounded;
      case 'Message': return Icons.chat_bubble_rounded;
      default: return Icons.event_rounded;
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case 'COMPLETED': color = const Color(0xFF10B981); break;
      case 'CANCELLED': color = const Color(0xFFEF4444); break;
      default: color = const Color(0xFF3B82F6);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(status, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }
}
