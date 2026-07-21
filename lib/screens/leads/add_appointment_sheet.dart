import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_theme.dart';
import '../../models/activity.dart';
import '../../providers/lead_provider.dart';
import '../../services/activity_service.dart';
import '../../services/notification_service.dart';

class AddAppointmentSheet extends StatefulWidget {
  final String leadId;
  final String assignedUserId;
  const AddAppointmentSheet({super.key, required this.leadId, required this.assignedUserId});

  @override
  State<AddAppointmentSheet> createState() => _AddAppointmentSheetState();
}

class _AddAppointmentSheetState extends State<AddAppointmentSheet> {
  final _noteCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _selectedType = 'Call';
  DateTime _scheduledAt = DateTime.now().add(const Duration(hours: 1));
  String? _selectedUserId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedUserId = widget.assignedUserId.isNotEmpty ? widget.assignedUserId : null;
  }

  @override
  void dispose() { _noteCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final users = context.read<LeadProvider>().users;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(4)))),
              const SizedBox(height: 20),
              Text('Schedule Appointment', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              const SizedBox(height: 20),
              Text('Type', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: activityTypes.map((t) {
                  final sel = _selectedType == t;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedType = t),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: sel ? AppTheme.primaryBlue : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: sel ? AppTheme.primaryBlue : const Color(0xFFE5E7EB), width: 1.5),
                      ),
                      child: Text(t, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: sel ? Colors.white : AppTheme.textSecondary)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Text('Schedule Date & Time', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickDateTime,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceGrey,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.event_rounded, size: 18, color: AppTheme.primaryBlue),
                    const SizedBox(width: 10),
                    Text(DateFormat('MMM d, yyyy · h:mm a').format(_scheduledAt),
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500)),
                  ]),
                ),
              ),
              if (users.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Assign To', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _selectedUserId,
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.person_outline_rounded, size: 20)),
                  items: users.map((u) => DropdownMenuItem(value: u.id, child: Text(u.name))).toList(),
                  onChanged: (v) => setState(() => _selectedUserId = v),
                  validator: (v) => v == null ? 'Please assign to a user' : null,
                ),
              ],
              const SizedBox(height: 16),
              Text('Note', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _noteCtrl,
                maxLines: 3,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Note is required' : null,
                decoration: InputDecoration(hintText: 'Add notes about this appointment...', hintStyle: GoogleFonts.inter(color: AppTheme.textTertiary)),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: _saving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text('Schedule Appointment', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// [TimeOfDay] only carries hour/minute, so a picked appointment time
  /// always has :00 seconds — comparing it against a full-precision
  /// `DateTime.now()` would reject the current minute as "past". Truncate
  /// `now` to the minute so the current minute counts as present, not past.
  bool _isPast(DateTime dt) {
    final now = DateTime.now();
    final currentMinute = DateTime(now.year, now.month, now.day, now.hour, now.minute);
    return dt.isBefore(currentMinute);
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledAt.isBefore(now) ? now : _scheduledAt,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledAt.isBefore(now) ? now : _scheduledAt),
    );
    if (time == null || !mounted) return;

    final picked = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    if (_isPast(picked)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a present or future time')),
      );
      return;
    }
    setState(() => _scheduledAt = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a user to assign')));
      return;
    }
    if (_isPast(_scheduledAt)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a present or future time')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final appointment = await ActivityService().createAppointment(
        leadId: widget.leadId,
        note: _noteCtrl.text.trim(),
        appointmentType: _selectedType,
        scheduledAt: _scheduledAt,
        assignedTo: _selectedUserId!,
      );
      await NotificationService.scheduleAppointmentNotification(appointment);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }
}
