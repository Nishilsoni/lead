import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_theme.dart';
import '../../models/activity.dart';
import '../../services/activity_service.dart';
import '../leads/lead_activities_screen.dart';

enum AppointmentBoardView { board, list }

/// Time buckets that mirror the web "Tasks & Appointments" board.
enum _Bucket { overdue, today, nextWeek, future }

extension _BucketMeta on _Bucket {
  String get label {
    switch (this) {
      case _Bucket.overdue:
        return 'Overdue';
      case _Bucket.today:
        return 'Today';
      case _Bucket.nextWeek:
        return 'Next Week';
      case _Bucket.future:
        return 'Future';
    }
  }

  Color get color {
    switch (this) {
      case _Bucket.overdue:
        return const Color(0xFFEF4444);
      case _Bucket.today:
        return const Color(0xFF3B82F6);
      case _Bucket.nextWeek:
        return const Color(0xFF10B981);
      case _Bucket.future:
        return const Color(0xFF8B5CF6);
    }
  }
}

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  final ActivityService _service = ActivityService();

  List<Appointment> _all = [];
  bool _loading = true;
  String? _error;

  AppointmentBoardView _view = AppointmentBoardView.board;

  // Filters
  String? _assigneeId; // null = all
  String _statusFilter = 'ALL'; // ALL / SCHEDULED / COMPLETED / CANCELLED
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ── Data ──────────────────────────────────────────────────────────

  Future<List<Appointment>> _fetch() {
    final now = DateTime.now();
    return _service.getAppointments(
      since: now.subtract(const Duration(days: 365)),
      until: now.add(const Duration(days: 365)),
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _fetch();
      if (!mounted) return;
      setState(() {
        _all = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _silentReload() async {
    try {
      final data = await _fetch();
      if (mounted) setState(() => _all = data);
    } catch (_) {/* keep existing data */}
  }

  bool get _hasFilters =>
      _assigneeId != null ||
      _statusFilter != 'ALL' ||
      _startDate != null ||
      _endDate != null;

  List<Appointment> get _filtered => _all.where((a) {
        if (_assigneeId != null && a.assignedUser.id != _assigneeId) {
          return false;
        }
        if (_statusFilter != 'ALL' && a.status != _statusFilter) return false;
        if (_startDate != null &&
            a.scheduledAt.isBefore(DateTime(
                _startDate!.year, _startDate!.month, _startDate!.day))) {
          return false;
        }
        if (_endDate != null &&
            a.scheduledAt.isAfter(DateTime(
                _endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59))) {
          return false;
        }
        return true;
      }).toList();

  Map<_Bucket, List<Appointment>> get _buckets {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final nextWeekEnd = today.add(const Duration(days: 7));
    final result = {
      _Bucket.overdue: <Appointment>[],
      _Bucket.today: <Appointment>[],
      _Bucket.nextWeek: <Appointment>[],
      _Bucket.future: <Appointment>[],
    };
    for (final a in _filtered) {
      final d =
          DateTime(a.scheduledAt.year, a.scheduledAt.month, a.scheduledAt.day);
      if (d.isBefore(today)) {
        result[_Bucket.overdue]!.add(a);
      } else if (d == today) {
        result[_Bucket.today]!.add(a);
      } else if (!d.isAfter(nextWeekEnd)) {
        result[_Bucket.nextWeek]!.add(a);
      } else {
        result[_Bucket.future]!.add(a);
      }
    }
    for (final list in result.values) {
      list.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    }
    return result;
  }

  Map<String, String> get _availableAssignees {
    final map = <String, String>{};
    for (final a in _all) {
      if (a.assignedUser.id.isNotEmpty) {
        map[a.assignedUser.id] = a.assignedUser.name;
      }
    }
    return map;
  }

  // ── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Text('Tasks & Appointments',
            style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary)),
        actions: [
          _viewToggle(),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _viewToggle() {
    Widget btn(IconData icon, AppointmentBoardView v) {
      final selected = _view == v;
      return GestureDetector(
        onTap: () => setState(() => _view = v),
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: selected ? AppTheme.primaryBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon,
              size: 18,
              color: selected ? Colors.white : AppTheme.textSecondary),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          btn(Icons.view_list_rounded, AppointmentBoardView.list),
          const SizedBox(width: 2),
          btn(Icons.grid_view_rounded, AppointmentBoardView.board),
        ],
      ),
    );
  }

  // ── Filter bar ────────────────────────────────────────────────────

  Widget _buildFilterBar() {
    final assigneeName =
        _assigneeId == null ? null : _availableAssignees[_assigneeId];
    String? dateLabel;
    if (_startDate != null || _endDate != null) {
      final s =
          _startDate != null ? DateFormat('MMM d').format(_startDate!) : '…';
      final e = _endDate != null ? DateFormat('MMM d').format(_endDate!) : '…';
      dateLabel = '$s – $e';
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _chip(
              icon: Icons.person_outline_rounded,
              label: assigneeName ?? 'Assignee',
              active: _assigneeId != null,
              onTap: _openAssigneeFilter,
            ),
            const SizedBox(width: 8),
            _chip(
              icon: Icons.flag_outlined,
              label: _statusFilter == 'ALL'
                  ? 'Status'
                  : _statusLabel(_statusFilter),
              active: _statusFilter != 'ALL',
              onTap: _openStatusFilter,
            ),
            const SizedBox(width: 8),
            _chip(
              icon: Icons.date_range_rounded,
              label: dateLabel ?? 'Date range',
              active: dateLabel != null,
              onTap: _pickDateRange,
            ),
            if (_hasFilters) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _clearFilters,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.close_rounded,
                          size: 15, color: Color(0xFFEF4444)),
                      const SizedBox(width: 5),
                      Text('Clear',
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFEF4444))),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chip({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Material(
      color:
          active ? AppTheme.primaryBlue.withValues(alpha: 0.08) : Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: active
                  ? AppTheme.primaryBlue.withValues(alpha: 0.4)
                  : const Color(0xFFE5E7EB),
            ),
          ),
          child: Row(
            children: [
              Icon(icon,
                  size: 15,
                  color:
                      active ? AppTheme.primaryBlue : AppTheme.textSecondary),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 140),
                child: Text(label,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: active
                            ? AppTheme.primaryBlue
                            : AppTheme.textSecondary)),
              ),
              const SizedBox(width: 2),
              Icon(Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color:
                      active ? AppTheme.primaryBlue : AppTheme.textTertiary),
            ],
          ),
        ),
      ),
    );
  }

  // ── Body dispatch ─────────────────────────────────────────────────

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 48, color: Color(0xFF9CA3AF)),
              const SizedBox(height: 12),
              Text('Failed to load',
                  style: GoogleFonts.inter(
                      fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      fontSize: 13, color: AppTheme.textTertiary)),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final buckets = _buckets;
    final total = buckets.values.fold<int>(0, (s, l) => s + l.length);
    if (total == 0) return _emptyState();

    return _view == AppointmentBoardView.board
        ? _buildBoardView(buckets)
        : _buildListView(buckets);
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.event_busy_rounded,
                  size: 34, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 16),
            Text(_hasFilters ? 'No matching appointments' : 'No appointments',
                style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 6),
            Text(
                _hasFilters
                    ? 'Try adjusting or clearing your filters.'
                    : 'Scheduled appointments will appear here.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 13, color: AppTheme.textTertiary)),
            if (_hasFilters) ...[
              const SizedBox(height: 16),
              OutlinedButton(
                  onPressed: _clearFilters,
                  child: const Text('Clear Filters')),
            ],
          ],
        ),
      ),
    );
  }

  // ── Board view (horizontal kanban columns) ────────────────────────

  Widget _buildBoardView(Map<_Bucket, List<Appointment>> buckets) {
    return RefreshIndicator(
      onRefresh: _load,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _Bucket.values.map((b) {
                final list = buckets[b]!;
                return Container(
                  width: 300,
                  height: constraints.maxHeight - 24,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFEEF2F6)),
                  ),
                  child: Column(
                    children: [
                      _columnHeader(b, list.length),
                      Expanded(
                        child: list.isEmpty
                            ? Center(
                                child: Text('Nothing here',
                                    style: GoogleFonts.inter(
                                        fontSize: 13,
                                        color: AppTheme.textTertiary)),
                              )
                            : ListView.builder(
                                padding:
                                    const EdgeInsets.fromLTRB(10, 4, 10, 12),
                                itemCount: list.length,
                                itemBuilder: (_, i) =>
                                    _appointmentCard(list[i], b),
                              ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }

  Widget _columnHeader(_Bucket b, int count) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFEEF2F6))),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: b.color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(b.label,
              style: GoogleFonts.inter(
                  fontSize: 14, fontWeight: FontWeight.w700, color: b.color)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: b.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('$count',
                style: GoogleFonts.inter(
                    fontSize: 12, fontWeight: FontWeight.w700, color: b.color)),
          ),
        ],
      ),
    );
  }

  // ── List view (vertical, grouped) ─────────────────────────────────

  Widget _buildListView(Map<_Bucket, List<Appointment>> buckets) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: _Bucket.values.where((b) => buckets[b]!.isNotEmpty).map((b) {
          final list = buckets[b]!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 10, 2, 8),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                          color: b.color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Text(b.label,
                        style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: b.color)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: b.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('${list.length}',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: b.color)),
                    ),
                  ],
                ),
              ),
              ...list.map((a) => _appointmentCard(a, b)),
            ],
          );
        }).toList(),
      ),
    );
  }

  // ── Appointment card ──────────────────────────────────────────────

  Widget _appointmentCard(Appointment a, _Bucket bucket) {
    return GestureDetector(
      onTap: () => _openLead(a),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3))
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: bucket.color,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(14),
                    bottomLeft: Radius.circular(14),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.business.name.isNotEmpty
                            ? a.business.name
                            : 'Appointment',
                        style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      _metaRow(
                          Icons.schedule_rounded,
                          DateFormat('d MMM yyyy, h:mm a')
                              .format(a.scheduledAt.toLocal())),
                      const SizedBox(height: 5),
                      _metaRow(_typeIcon(a.appointmentType),
                          'Type: ${a.appointmentType}'),
                      const SizedBox(height: 5),
                      _metaRow(Icons.person_outline_rounded,
                          'Assigned: ${a.assignedUser.name}'),
                      const SizedBox(height: 12),
                      _statusDropdown(a),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metaRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppTheme.textTertiary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text,
              style: GoogleFonts.inter(
                  fontSize: 13, color: AppTheme.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  Widget _statusDropdown(Appointment a) {
    final color = _statusColor(a.status);
    return GestureDetector(
      onTap: () => _changeStatus(a),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 7),
            Text(_statusLabel(a.status),
                style: GoogleFonts.inter(
                    fontSize: 12, fontWeight: FontWeight.w700, color: color)),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: color),
          ],
        ),
      ),
    );
  }

  // ── Actions ───────────────────────────────────────────────────────

  void _openLead(Appointment a) {
    if (a.leadId.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LeadActivitiesScreen(
          leadId: a.leadId,
          leadName: a.business.name,
          assignedUserId: a.assignedUser.id,
        ),
      ),
    ).then((_) => _silentReload());
  }

  Future<void> _changeStatus(Appointment a) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _StatusSheet(current: a.status),
    );
    if (selected == null || selected == a.status) return;

    String note = '';
    if (selected != 'SCHEDULED') {
      final entered = await _askNote(selected);
      if (entered == null) return; // dialog dismissed
      note = entered;
    }

    try {
      await _service.updateAppointmentStatus(
        appointmentId: a.id,
        status: selected,
        note: note,
        appointmentType: a.appointmentType,
        scheduledAt: a.scheduledAt,
        assignedTo: a.assignedUser.id,
      );
      await _silentReload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Marked as ${_statusLabel(selected)}'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: _statusColor(selected),
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

  Future<String?> _askNote(String status) async {
    final ctrl = TextEditingController();
    final isDone = status == 'COMPLETED';
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(isDone ? 'Complete Appointment' : 'Cancel Appointment',
            style:
                GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add an optional note.',
                style: GoogleFonts.inter(
                    fontSize: 14, color: AppTheme.textSecondary)),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Note (optional)…',
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
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Back',
                style: GoogleFonts.inter(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  isDone ? const Color(0xFF10B981) : const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Submit',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ── Filter sheets ─────────────────────────────────────────────────

  void _openAssigneeFilter() {
    final assignees = _availableAssignees;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _SelectSheet(
        title: 'Filter by Assignee',
        options: {'__all__': 'All assignees', ...assignees},
        selected: _assigneeId ?? '__all__',
        onSelect: (key) =>
            setState(() => _assigneeId = key == '__all__' ? null : key),
      ),
    );
  }

  void _openStatusFilter() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _SelectSheet(
        title: 'Filter by Status',
        options: const {
          'ALL': 'All statuses',
          'SCHEDULED': 'Scheduled',
          'COMPLETED': 'Completed',
          'CANCELLED': 'Cancelled',
        },
        selected: _statusFilter,
        onSelect: (key) => setState(() => _statusFilter = key),
      ),
    );
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 2),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context)
              .colorScheme
              .copyWith(primary: AppTheme.primaryBlue),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  void _clearFilters() {
    setState(() {
      _assigneeId = null;
      _statusFilter = 'ALL';
      _startDate = null;
      _endDate = null;
    });
  }

  // ── Helpers ───────────────────────────────────────────────────────

  String _statusLabel(String s) {
    switch (s) {
      case 'SCHEDULED':
        return 'Scheduled';
      case 'COMPLETED':
        return 'Completed';
      case 'CANCELLED':
        return 'Cancelled';
      default:
        return s;
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'COMPLETED':
        return const Color(0xFF10B981);
      case 'CANCELLED':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF3B82F6);
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'Call':
        return Icons.phone_rounded;
      case 'Meeting':
        return Icons.groups_rounded;
      case 'Online':
        return Icons.videocam_rounded;
      case 'Email':
        return Icons.email_rounded;
      case 'Message':
        return Icons.chat_bubble_rounded;
      default:
        return Icons.event_rounded;
    }
  }
}

// ── Single-select bottom sheet ──────────────────────────────────────

class _SelectSheet extends StatelessWidget {
  final String title;
  final Map<String, String> options; // key -> label
  final String selected;
  final ValueChanged<String> onSelect;

  const _SelectSheet({
    required this.title,
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(title,
                  style: GoogleFonts.inter(
                      fontSize: 17, fontWeight: FontWeight.w700)),
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              children: options.entries.map((e) {
                final isSel = e.key == selected;
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      onSelect(e.key);
                      Navigator.pop(context);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 13),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(e.value,
                                style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: isSel
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isSel
                                        ? AppTheme.primaryBlue
                                        : AppTheme.textPrimary)),
                          ),
                          if (isSel)
                            const Icon(Icons.check_rounded,
                                size: 20, color: AppTheme.primaryBlue),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }
}

// ── Status change bottom sheet ──────────────────────────────────────

class _StatusSheet extends StatelessWidget {
  final String current;
  const _StatusSheet({required this.current});

  static const _statuses = {
    'SCHEDULED': ('Scheduled', Color(0xFF3B82F6), Icons.schedule_rounded),
    'COMPLETED': ('Completed', Color(0xFF10B981), Icons.check_circle_rounded),
    'CANCELLED': ('Cancelled', Color(0xFFEF4444), Icons.cancel_rounded),
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Change Status',
                  style: GoogleFonts.inter(
                      fontSize: 17, fontWeight: FontWeight.w700)),
            ),
          ),
          ..._statuses.entries.map((e) {
            final (label, color, icon) = e.value;
            final isCurrent = e.key == current;
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => Navigator.pop(context, e.key),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, size: 19, color: color),
                      ),
                      const SizedBox(width: 14),
                      Text(label,
                          style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary)),
                      const Spacer(),
                      if (isCurrent)
                        Icon(Icons.check_rounded, size: 20, color: color),
                    ],
                  ),
                ),
              ),
            );
          }),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 12),
        ],
      ),
    );
  }
}
