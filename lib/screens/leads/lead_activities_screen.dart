import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_theme.dart';
import '../../core/utils/call_logging_helper.dart';
import '../../models/activity.dart';
import '../../models/attachment.dart';
import '../../models/contact.dart';
import '../../services/activity_service.dart';
import '../../services/attachment_service.dart';
import '../../services/contact_service.dart';
import '../../services/lead_service.dart';
import '../widgets/empty_state.dart';
import 'add_activity_sheet.dart';
import 'add_appointment_sheet.dart';

class LeadActivitiesScreen extends StatefulWidget {
  final String leadId;
  final String leadName;
  final String assignedUserId;
  final String mobile;
  final String email;
  final String stage;
  final String businessId;

  const LeadActivitiesScreen({
    super.key,
    required this.leadId,
    required this.leadName,
    required this.assignedUserId,
    this.mobile = '',
    this.email = '',
    this.stage = '',
    this.businessId = '',
  });

  @override
  State<LeadActivitiesScreen> createState() => _LeadActivitiesScreenState();
}

class _LeadActivitiesScreenState extends State<LeadActivitiesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ActivityService _service = ActivityService();
  final LeadService _leadService = LeadService();
  final AttachmentService _attachmentService = AttachmentService();
  final ContactService _contactService = ContactService();

  List<Interaction> _interactions = [];
  List<Appointment> _appointments = [];
  List<LeadAttachment> _attachments = [];
  List<Contact> _contacts = [];

  bool _loadingInteractions = true;
  bool _loadingAppointments = true;
  bool _loadingAttachments = true;
  bool _loadingContacts = false;
  bool _uploadingAttachment = false;

  String? _interactionError;
  String? _appointmentError;
  String? _attachmentError;
  String? _contactError;

  late String _mobile;
  late String _email;
  late String _stage;
  late String _businessId;
  bool _loadingLead = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _mobile = widget.mobile;
    _email = widget.email;
    _stage = widget.stage;
    _businessId = widget.businessId;
    _loadInteractions();
    _loadAppointments();
    _loadAttachments();
    if (_businessId.isNotEmpty) {
      _loadContacts();
    }
    if (_mobile.isEmpty && _email.isEmpty && _stage.isEmpty) {
      _fetchLeadDetails();
    }
    _tabController.addListener(() {
      if (_tabController.index == 3 && _contacts.isEmpty && !_loadingContacts && _contactError == null) {
        if (_businessId.isNotEmpty) _loadContacts();
      }
    });
  }

  Future<void> _fetchLeadDetails() async {
    setState(() => _loadingLead = true);
    try {
      final lead = await _leadService.getLeadById(widget.leadId);
      if (mounted) {
        setState(() {
          _mobile = lead.business.mobile;
          _email = lead.business.email;
          _stage = lead.stage;
          _loadingLead = false;
          if (_businessId.isEmpty) {
            _businessId = lead.business.id;
            _loadContacts();
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingLead = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Data loading ──────────────────────────────────────────────────

  Future<void> _loadInteractions() async {
    setState(() {
      _loadingInteractions = true;
      _interactionError = null;
    });
    try {
      final data = await _service.getInteractions(leadId: widget.leadId);
      if (mounted) setState(() { _interactions = data; _loadingInteractions = false; });
    } catch (e) {
      if (mounted) setState(() { _interactionError = e.toString(); _loadingInteractions = false; });
    }
  }

  Future<void> _loadAppointments() async {
    setState(() {
      _loadingAppointments = true;
      _appointmentError = null;
    });
    try {
      final data = await _service.getAppointments(leadId: widget.leadId);
      if (mounted) setState(() { _appointments = data; _loadingAppointments = false; });
    } catch (e) {
      if (mounted) setState(() { _appointmentError = e.toString(); _loadingAppointments = false; });
    }
  }

  Future<void> _loadAttachments() async {
    setState(() {
      _loadingAttachments = true;
      _attachmentError = null;
    });
    try {
      final data = await _attachmentService.getAttachments(leadId: widget.leadId);
      if (mounted) setState(() { _attachments = data; _loadingAttachments = false; });
    } catch (e) {
      if (mounted) setState(() { _attachmentError = e.toString(); _loadingAttachments = false; });
    }
  }

  Future<void> _loadContacts() async {
    if (_businessId.isEmpty) return;
    setState(() {
      _loadingContacts = true;
      _contactError = null;
    });
    try {
      final data = await _contactService.getContacts(_businessId);
      if (mounted) setState(() { _contacts = data; _loadingContacts = false; });
    } catch (e) {
      if (mounted) setState(() { _contactError = e.toString(); _loadingContacts = false; });
    }
  }

  Future<void> _updateAppointmentStatus(
      Appointment appt, String status, String note) async {
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  // ── Attachment actions ────────────────────────────────────────────

  Future<void> _pickAndUpload() async {
    if (_attachments.length >= AttachmentService.maxFiles) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maximum 5 attachments allowed per lead.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: true,
      type: FileType.any,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;

    if ((file.size) > AttachmentService.maxFileSizeBytes) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('File exceeds 10 MB limit.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    setState(() => _uploadingAttachment = true);
    try {
      await _attachmentService.uploadAttachment(leadId: widget.leadId, file: file);
      await _loadAttachments();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('File uploaded successfully'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingAttachment = false);
    }
  }

  Future<void> _deleteAttachment(LeadAttachment attachment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 8))
            ],
          ),
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete_rounded,
                    color: Color(0xFFEF4444), size: 26),
              ),
              const SizedBox(height: 16),
              Text('Delete Attachment',
                  style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF111827))),
              const SizedBox(height: 8),
              Text(
                '"${attachment.fileName}" will be permanently deleted.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 14, color: const Color(0xFF6B7280), height: 1.5),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text('Cancel',
                          style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF374151))),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: const Color(0xFFEF4444),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text('Delete',
                          style: GoogleFonts.inter(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true) return;

    try {
      await _attachmentService.deleteAttachment(
        leadId: widget.leadId,
        attachmentId: attachment.id,
      );
      await _loadAttachments();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Attachment deleted'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  // ── Contact actions ───────────────────────────────────────────────

  void _addContact() {
    if (_businessId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lead data still loading, please wait…'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    _showContactSheet();
  }

  void _editContact(Contact contact) => _showContactSheet(existing: contact);

  void _showContactSheet({Contact? existing}) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ContactFormSheet(
        businessId: _businessId,
        existing: existing,
        service: _contactService,
      ),
    );
    if (result == true) _loadContacts();
  }

  Future<void> _deleteContact(Contact contact) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 8))
            ],
          ),
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_remove_rounded,
                    color: Color(0xFFEF4444), size: 26),
              ),
              const SizedBox(height: 16),
              Text('Remove Contact',
                  style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF111827))),
              const SizedBox(height: 8),
              Text(
                contact.name.isNotEmpty
                    ? '"${contact.name}" will be permanently removed.'
                    : 'This contact will be permanently removed.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 14, color: const Color(0xFF6B7280), height: 1.5),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text('Cancel',
                          style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF374151))),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: const Color(0xFFEF4444),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text('Remove',
                          style: GoogleFonts.inter(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true) return;

    try {
      await _contactService.deleteContact(contact.id);
      if (mounted) {
        setState(() => _contacts.removeWhere((c) => c.id == contact.id));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contact removed'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────

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
            Text('Activities',
                style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary)),
            Text(widget.leadName,
                style: GoogleFonts.inter(
                    fontSize: 12, color: AppTheme.textSecondary)),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelStyle:
              GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
          unselectedLabelStyle:
              GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
          labelColor: AppTheme.primaryBlue,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primaryBlue,
          indicatorWeight: 2.5,
          labelPadding: const EdgeInsets.symmetric(horizontal: 16),
          tabs: [
            Tab(text: 'Interactions (${_interactions.length})'),
            Tab(text: 'Appointments (${_appointments.length})'),
            Tab(text: 'Attachments (${_attachments.length})'),
            Tab(text: 'Contacts (${_contacts.length})'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildLeadHeader(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildInteractionsTab(),
                _buildAppointmentsTab(),
                _buildAttachmentsTab(),
                _buildContactsTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _tabController,
        builder: (context, _) {
          final idx = _tabController.index;
          if (idx == 0) {
            return FloatingActionButton.extended(
              onPressed: _addInteraction,
              icon: const Icon(Icons.add_rounded),
              label: Text('Log Activity',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            );
          }
          if (idx == 1) {
            return FloatingActionButton.extended(
              onPressed: _addAppointment,
              icon: const Icon(Icons.add_rounded),
              label: Text('Schedule',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            );
          }
          if (idx == 3) {
            return FloatingActionButton.extended(
              onPressed: _addContact,
              icon: const Icon(Icons.person_add_rounded),
              label: Text('Add Contact',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            );
          }
          // Attachments tab
          final canUpload = _attachments.length < AttachmentService.maxFiles;
          return FloatingActionButton.extended(
            onPressed:
                canUpload && !_uploadingAttachment ? _pickAndUpload : null,
            backgroundColor: canUpload
                ? AppTheme.primaryBlue
                : const Color(0xFF94A3B8),
            icon: _uploadingAttachment
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.upload_rounded),
            label: Text(
              _uploadingAttachment
                  ? 'Uploading…'
                  : canUpload
                      ? 'Upload File'
                      : 'Limit Reached',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          );
        },
      ),
    );
  }

  // ── Lead header ───────────────────────────────────────────────────

  Widget _buildLeadHeader() {
    if (_loadingLead) {
      return Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                  color: Color(0xFFE5E7EB), shape: BoxShape.circle),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                      height: 14,
                      width: 160,
                      decoration: BoxDecoration(
                          color: const Color(0xFFE5E7EB),
                          borderRadius: BorderRadius.circular(4))),
                  const SizedBox(height: 8),
                  Container(
                      height: 11,
                      width: 120,
                      decoration: BoxDecoration(
                          color: const Color(0xFFE5E7EB),
                          borderRadius: BorderRadius.circular(4))),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final hasMobile = _mobile.isNotEmpty;
    final hasEmail = _email.isNotEmpty;
    final hasStage = _stage.isNotEmpty;

    Color stageColor;
    switch (_stage.toUpperCase()) {
      case 'WON':
        stageColor = const Color(0xFF10B981);
        break;
      case 'LOST':
        stageColor = const Color(0xFFEF4444);
        break;
      case 'NEGOTIATION':
        stageColor = const Color(0xFFF59E0B);
        break;
      case 'PROPOSAL':
        stageColor = const Color(0xFF8B5CF6);
        break;
      case 'QUALIFIED':
        stageColor = const Color(0xFF3B82F6);
        break;
      default:
        stageColor = const Color(0xFF6B7280);
    }

    final initial =
        widget.leadName.isNotEmpty ? widget.leadName[0].toUpperCase() : '?';

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(initial,
                  style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryBlue)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.leadName,
                    style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary),
                    softWrap: true),
                const SizedBox(height: 5),
                Row(
                  children: [
                    if (hasStage) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: stageColor.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                              color: stageColor.withValues(alpha: 0.25)),
                        ),
                        child: Text(_stage,
                            style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: stageColor)),
                      ),
                      if (hasEmail) const SizedBox(width: 8),
                    ],
                    if (hasEmail)
                      Expanded(
                        child: Row(
                          children: [
                            Icon(Icons.email_outlined,
                                size: 12, color: AppTheme.textTertiary),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(_email,
                                  style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: AppTheme.textSecondary),
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (hasMobile) ...[
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () => CallLoggingHelper.callAndLog(
                context: context,
                phone: _mobile,
                leadId: widget.leadId,
                leadName: widget.leadName,
              ),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: const Color(0xFF10B981).withValues(alpha: 0.35)),
                ),
                child: const Icon(Icons.phone_rounded,
                    size: 20, color: Color(0xFF10B981)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Interactions tab ──────────────────────────────────────────────

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

  // ── Appointments tab ──────────────────────────────────────────────

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

  // ── Attachments tab ───────────────────────────────────────────────

  Widget _buildAttachmentsTab() {
    if (_loadingAttachments) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_attachmentError != null) {
      return EmptyState(
        title: 'Failed to load',
        subtitle: _attachmentError!,
        icon: Icons.error_outline_rounded,
        actionLabel: 'Retry',
        onAction: _loadAttachments,
      );
    }

    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              Icon(Icons.attach_file_rounded,
                  size: 16, color: AppTheme.textTertiary),
              const SizedBox(width: 6),
              Text(
                '${_attachments.length} / ${AttachmentService.maxFiles} files',
                style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondary),
              ),
              const Spacer(),
              Text(
                'Max 10 MB each',
                style: GoogleFonts.inter(
                    fontSize: 12, color: AppTheme.textTertiary),
              ),
            ],
          ),
        ),
        Container(height: 1, color: const Color(0xFFF1F5F9)),
        if (_attachments.isEmpty)
          Expanded(
            child: EmptyState(
              title: 'No attachments yet',
              subtitle: 'Upload files like contracts, photos, or documents',
              icon: Icons.folder_open_rounded,
              actionLabel: 'Upload File',
              onAction: _pickAndUpload,
            ),
          )
        else
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadAttachments,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                itemCount: _attachments.length,
                itemBuilder: (_, i) => _AttachmentCard(
                  attachment: _attachments[i],
                  onDelete: () => _deleteAttachment(_attachments[i]),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ── Contacts tab ──────────────────────────────────────────────────

  Widget _buildContactsTab() {
    if (_loadingContacts) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_contactError != null) {
      return EmptyState(
        title: 'Failed to load contacts',
        subtitle: _contactError!,
        icon: Icons.error_outline_rounded,
        actionLabel: 'Retry',
        onAction: _loadContacts,
      );
    }
    if (_businessId.isEmpty && !_loadingLead) {
      return const EmptyState(
        title: 'Lead data unavailable',
        subtitle: 'Could not determine the business for this lead',
        icon: Icons.person_off_rounded,
      );
    }
    if (_contacts.isEmpty) {
      return EmptyState(
        title: 'No contacts yet',
        subtitle: 'Add extra contacts for this lead\'s business',
        icon: Icons.contacts_rounded,
        actionLabel: 'Add Contact',
        onAction: _addContact,
      );
    }
    return RefreshIndicator(
      onRefresh: _loadContacts,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount: _contacts.length,
        itemBuilder: (_, i) => _ContactCard(
          contact: _contacts[i],
          leadId: widget.leadId,
          leadName: widget.leadName,
          onEdit: () => _editContact(_contacts[i]),
          onDelete: () => _deleteContact(_contacts[i]),
        ),
      ),
    );
  }

  // ── Action helpers ────────────────────────────────────────────────

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

// ── Contact Card ──────────────────────────────────────────────────────────────

class _ContactCard extends StatelessWidget {
  final Contact contact;
  final String leadId;
  final String leadName;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ContactCard({
    required this.contact,
    required this.leadId,
    required this.leadName,
    required this.onEdit,
    required this.onDelete,
  });

  static const List<Color> _avatarPalette = [
    Color(0xFF3B82F6),
    Color(0xFF8B5CF6),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
    Color(0xFF06B6D4),
    Color(0xFFEC4899),
    Color(0xFF6366F1),
  ];

  Color get _avatarColor {
    if (contact.id.isEmpty) return _avatarPalette[0];
    return _avatarPalette[contact.id.codeUnits.first % _avatarPalette.length];
  }

  @override
  Widget build(BuildContext context) {
    final hasMobile = contact.mobile.isNotEmpty;
    final hasEmail = contact.email.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: _avatarColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  contact.initials,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _avatarColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name
                  if (contact.name.isNotEmpty)
                    Text(
                      contact.name,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF111827),
                      ),
                    ),

                  if (contact.name.isNotEmpty && (hasMobile || hasEmail))
                    const SizedBox(height: 8),

                  // Mobile
                  if (hasMobile)
                    GestureDetector(
                      onTap: () => CallLoggingHelper.callAndLog(
                        context: context,
                        phone: contact.mobile,
                        leadId: leadId,
                        leadName: leadName,
                      ),
                      onLongPress: () {
                        Clipboard.setData(ClipboardData(text: contact.mobile));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Phone number copied'),
                            behavior: SnackBarBehavior.floating,
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981)
                                  .withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.phone_rounded,
                                size: 14, color: Color(0xFF10B981)),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            contact.mobile,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ),
                    ),

                  if (hasMobile && hasEmail) const SizedBox(height: 6),

                  // Email
                  if (hasEmail)
                    GestureDetector(
                      onTap: () async {
                        final uri =
                            Uri.parse('mailto:${contact.email}');
                        if (await canLaunchUrl(uri)) launchUrl(uri);
                      },
                      onLongPress: () {
                        Clipboard.setData(ClipboardData(text: contact.email));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Email address copied'),
                            behavior: SnackBarBehavior.floating,
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B82F6)
                                  .withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.email_rounded,
                                size: 14, color: Color(0xFF3B82F6)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              contact.email,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF3B82F6),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // Actions menu
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded,
                  size: 20, color: Color(0xFF9CA3AF)),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      const Icon(Icons.edit_rounded,
                          size: 17, color: Color(0xFF6B7280)),
                      const SizedBox(width: 10),
                      Text('Edit',
                          style: GoogleFonts.inter(
                              fontSize: 14, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      const Icon(Icons.delete_outline_rounded,
                          size: 17, color: Color(0xFFEF4444)),
                      const SizedBox(width: 10),
                      Text('Remove',
                          style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFFEF4444))),
                    ],
                  ),
                ),
              ],
              onSelected: (v) {
                if (v == 'edit') onEdit();
                if (v == 'delete') onDelete();
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Contact Form Sheet ────────────────────────────────────────────────────────

class _ContactFormSheet extends StatefulWidget {
  final String businessId;
  final Contact? existing;
  final ContactService service;

  const _ContactFormSheet({
    required this.businessId,
    required this.service,
    this.existing,
  });

  @override
  State<_ContactFormSheet> createState() => _ContactFormSheetState();
}

class _ContactFormSheetState extends State<_ContactFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _mobileCtrl;
  late final TextEditingController _emailCtrl;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl =
        TextEditingController(text: widget.existing?.name ?? '');
    _mobileCtrl =
        TextEditingController(text: widget.existing?.mobile ?? '');
    _emailCtrl =
        TextEditingController(text: widget.existing?.email ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _mobileCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final name = _nameCtrl.text.trim();
    final mobile = _mobileCtrl.text.trim();
    final email = _emailCtrl.text.trim();

    if (name.isEmpty && mobile.isEmpty && email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in at least one field'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      if (_isEdit) {
        await widget.service.updateContact(
          contactId: widget.existing!.id,
          businessId: widget.businessId,
          name: name,
          mobile: mobile,
          email: email,
        );
      } else {
        await widget.service.createContact(
          businessId: widget.businessId,
          name: name,
          mobile: mobile,
          email: email,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 20),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Title row
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _isEdit
                        ? Icons.edit_rounded
                        : Icons.person_add_rounded,
                    color: AppTheme.primaryBlue,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _isEdit ? 'Edit Contact' : 'Add Contact',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF111827),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Name field
            _FormField(
              controller: _nameCtrl,
              label: 'Name',
              hint: 'e.g. Rahul Sharma',
              icon: Icons.person_outline_rounded,
            ),
            const SizedBox(height: 14),

            // Mobile field
            _FormField(
              controller: _mobileCtrl,
              label: 'Mobile',
              hint: 'e.g. +91 98765 43210',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 14),

            // Email field
            _FormField(
              controller: _emailCtrl,
              label: 'Email',
              hint: 'e.g. rahul@company.com',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v != null && v.isNotEmpty && !v.contains('@')) {
                  return 'Enter a valid email';
                }
                return null;
              },
            ),
            const SizedBox(height: 28),

            // Save button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white))
                    : Text(
                        _isEdit ? 'Save Changes' : 'Add Contact',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;

  const _FormField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType = TextInputType.text,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF374151))),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF111827)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                GoogleFonts.inter(fontSize: 14, color: const Color(0xFF9CA3AF)),
            prefixIcon: Icon(icon, size: 18, color: const Color(0xFF9CA3AF)),
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
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
              borderSide:
                  const BorderSide(color: AppTheme.primaryBlue, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFEF4444)),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        ),
      ],
    );
  }
}

// ── Attachment Card ───────────────────────────────────────────────────────────

class _AttachmentCard extends StatelessWidget {
  final LeadAttachment attachment;
  final VoidCallback onDelete;

  const _AttachmentCard({required this.attachment, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: InkWell(
        onTap: () => _openFile(context),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: attachment.iconColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(attachment.icon, color: attachment.iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      attachment.fileName,
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (attachment.fileSizeFormatted.isNotEmpty) ...[
                          Text(attachment.fileSizeFormatted,
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppTheme.textTertiary)),
                          const SizedBox(width: 8),
                          Container(
                              width: 3,
                              height: 3,
                              decoration: const BoxDecoration(
                                  color: Color(0xFFD1D5DB),
                                  shape: BoxShape.circle)),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          DateFormat('MMM d, yyyy')
                              .format(attachment.createdAt.toLocal()),
                          style: GoogleFonts.inter(
                              fontSize: 12, color: AppTheme.textTertiary),
                        ),
                      ],
                    ),
                    if (attachment.uploadedByUser != null) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(Icons.person_outline_rounded,
                              size: 12, color: AppTheme.textTertiary),
                          const SizedBox(width: 3),
                          Text(
                            attachment.uploadedByUser!.name,
                            style: GoogleFonts.inter(
                                fontSize: 12, color: AppTheme.textTertiary),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                children: [
                  IconButton(
                    icon: const Icon(Icons.open_in_new_rounded,
                        size: 18, color: Color(0xFF6B7280)),
                    onPressed: () => _openFile(context),
                    tooltip: 'Open file',
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(height: 4),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded,
                        size: 18, color: Color(0xFFEF4444)),
                    onPressed: onDelete,
                    tooltip: 'Delete',
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openFile(BuildContext context) async {
    if (attachment.fileUrl.isEmpty) return;
    final uri = Uri.tryParse(attachment.fileUrl);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open the file.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
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
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(interaction.interactionType,
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: color)),
                      ),
                      const Spacer(),
                      Text(
                        DateFormat('MMM d, h:mm a')
                            .format(interaction.interactedAt.toLocal()),
                        style: GoogleFonts.inter(
                            fontSize: 11, color: AppTheme.textTertiary),
                      ),
                    ],
                  ),
                  if (interaction.note.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(interaction.note,
                        style: GoogleFonts.inter(
                            fontSize: 14,
                            color: AppTheme.textPrimary,
                            height: 1.4)),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.person_outline_rounded,
                          size: 13, color: AppTheme.textTertiary),
                      const SizedBox(width: 4),
                      Text(interaction.interactedByUser.name,
                          style: GoogleFonts.inter(
                              fontSize: 12, color: AppTheme.textTertiary)),
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

  const _AppointmentCard(
      {required this.appointment, required this.onStatusChange});

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
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
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
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(appointment.appointmentType,
                                style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: color)),
                          ),
                          const SizedBox(width: 8),
                          _StatusBadge(status: appointment.status),
                          const Spacer(),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.schedule_rounded,
                              size: 14, color: AppTheme.textTertiary),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('MMM d, yyyy · h:mm a')
                                .format(appointment.scheduledAt.toLocal()),
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary),
                          ),
                        ],
                      ),
                      if (appointment.note.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(appointment.note,
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                                height: 1.4)),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.person_outline_rounded,
                              size: 13, color: AppTheme.textTertiary),
                          const SizedBox(width: 4),
                          Text(appointment.assignedUser.name,
                              style: GoogleFonts.inter(
                                  fontSize: 12, color: AppTheme.textTertiary)),
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
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        backgroundColor:
                            const Color(0xFF10B981).withValues(alpha: 0.08),
                      ),
                      child: Text('Mark Done',
                          style: GoogleFonts.inter(
                              fontSize: 13, fontWeight: FontWeight.w600)),
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
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        backgroundColor:
                            const Color(0xFFEF4444).withValues(alpha: 0.08),
                      ),
                      child: Text('Cancel',
                          style: GoogleFonts.inter(
                              fontSize: 13, fontWeight: FontWeight.w600)),
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
              style: GoogleFonts.inter(
                  fontSize: 14, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: noteController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Enter note here...',
                hintStyle: GoogleFonts.inter(
                    color: AppTheme.textTertiary, fontSize: 14),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: AppTheme.primaryBlue, width: 2)),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Back',
                style: GoogleFonts.inter(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, noteController.text.trim());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  isDone ? const Color(0xFF10B981) : const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Submit',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
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
      child: Text(status,
          style: GoogleFonts.inter(
              fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }
}
