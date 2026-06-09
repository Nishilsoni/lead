import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/activity_service.dart';
import '../constants/app_theme.dart';
import 'phone_call_helper.dart';
import 'snackbar_helper.dart';

class CallLoggingHelper {
  static Future<void> callAndLog({
    required BuildContext context,
    required String phone,
    required String leadId,
    required String leadName,
  }) async {
    final success = await PhoneCallHelper.call(phone);

    if (!success) {
      if (context.mounted) {
        SnackbarHelper.showError(
          context,
          'Could not start the call. Please check call permission.',
        );
      }
      return;
    }

    if (context.mounted) {
      _showCallNotesDialog(
        context: context,
        phone: phone,
        leadId: leadId,
        leadName: leadName,
      );
    }
  }

  static void _showCallNotesDialog({
    required BuildContext context,
    required String phone,
    required String leadId,
    required String leadName,
  }) {
    showDialog(
      context: context,
      builder: (_) => _CallNotesDialog(
        phone: phone,
        leadId: leadId,
        leadName: leadName,
      ),
    );
  }
}

class _CallNotesDialog extends StatefulWidget {
  final String phone;
  final String leadId;
  final String leadName;

  const _CallNotesDialog({
    required this.phone,
    required this.leadId,
    required this.leadName,
  });

  @override
  State<_CallNotesDialog> createState() => _CallNotesDialogState();
}

class _CallNotesDialogState extends State<_CallNotesDialog> {
  late TextEditingController _notesController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with gradient
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.primaryBlue.withValues(alpha: 0.8),
                    AppTheme.primaryBlue,
                  ],
                ),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.call_made_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Call Completed',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add notes about your call with ${widget.leadName}',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Phone display
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.phone, color: Colors.grey[600], size: 18),
                        const SizedBox(width: 10),
                        Text(
                          widget.phone,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Notes input
                  Text(
                    'Call Notes (Optional)',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _notesController,
                    enabled: !_isLoading,
                    maxLines: 5,
                    maxLength: 500,
                    decoration: InputDecoration(
                      hintText:
                          'What did you discuss? Any follow-ups, decisions, or important details...',
                      hintStyle: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.grey[400],
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: AppTheme.primaryBlue, width: 2),
                      ),
                      counterStyle: GoogleFonts.inter(fontSize: 12),
                    ),
                    style: GoogleFonts.inter(fontSize: 13),
                  ),
                  const SizedBox(height: 20),

                  // Info box
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: AppTheme.primaryBlue,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Notes help you and your team remember the call details',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppTheme.primaryBlue,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: _isLoading ? null : () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: Colors.grey[300]!,
                              ),
                            ),
                          ),
                          child: Text(
                            'Skip',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _saveCallLog,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryBlue,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            disabledBackgroundColor: Colors.grey[300],
                          ),
                          child: _isLoading
                              ? SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white.withValues(alpha: 0.8),
                                    ),
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  'Save & Close',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
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

  Future<void> _saveCallLog() async {
    setState(() => _isLoading = true);
    try {
      await ActivityService().createInteraction(
        leadId: widget.leadId,
        interactionType: 'Call',
        interactedAt: DateTime.now(),
        note: _notesController.text.trim().isEmpty
            ? 'Call completed with ${widget.leadName}'
            : _notesController.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context);
        SnackbarHelper.showSuccess(
          context,
          'Call log saved successfully',
        );
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(
          context,
          'Failed to save call log',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
