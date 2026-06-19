import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/app_theme.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../services/lead_service.dart';

/// Export + bulk-upload flows for leads, shared by the Leads screen menu.
class LeadBulkActions {
  static final LeadService _service = LeadService();

  // ── Export Excel ────────────────────────────────────────────────────────────

  static Future<void> exportExcel(BuildContext context) async {
    // Capture everything we need from context before any async gap.
    final navigator = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.of(context);
    final box = context.findRenderObject() as RenderBox?;
    final screenSize = MediaQuery.sizeOf(context);
    final shareOrigin = box != null
        ? box.localToGlobal(Offset.zero) & box.size
        : Rect.fromCenter(
            center: Offset(screenSize.width / 2, screenSize.height / 2),
            width: 100,
            height: 100,
          );

    _showProgress(context, 'Preparing export…');
    String? errorMessage;
    List<int> bytes = [];

    try {
      bytes = await _service.exportLeads();
    } catch (e) {
      errorMessage = 'Export failed: ${_msg(e)}';
    }

    // Always dismiss the progress dialog exactly once.
    navigator.pop();

    if (errorMessage != null) {
      SnackbarHelper.showErrorOnMessenger(messenger, errorMessage);
      return;
    }

    if (bytes.isEmpty) {
      SnackbarHelper.showErrorOnMessenger(messenger, 'No data to export');
      return;
    }

    try {
      final filename =
          'leads_${DateTime.now().toIso8601String().split('T').first}.csv';
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(bytes, flush: true);

      await Share.shareXFiles(
        [XFile(file.path, name: filename, mimeType: _csvMime)],
        subject: 'Leads export',
        sharePositionOrigin: shareOrigin,
      );
    } catch (e) {
      SnackbarHelper.showErrorOnMessenger(
          messenger, 'Could not open share sheet: ${_msg(e)}');
    }
  }

  static const String _csvMime = 'text/csv';

  // ── Bulk Upload ───────────────────────────────────────────────────────────────

  /// Returns true if any leads were uploaded (so the caller can refresh).
  static Future<bool> bulkUpload(BuildContext context) async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return false;

    final file = picked.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      if (context.mounted) {
        SnackbarHelper.showError(context, 'Could not read the selected file');
      }
      return false;
    }

    if (!context.mounted) return false;
    _showProgress(context, 'Parsing ${file.name}…');
    try {
      final result = await _service.bulkUploadLeads(
        bytes: bytes,
        filename: file.name,
      );
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      if (context.mounted) _showResult(context, result);
      return (result['created'] ?? 0) > 0;
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        SnackbarHelper.showError(context, 'Upload failed: ${_msg(e)}');
      }
      return false;
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  static void _showProgress(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              const SizedBox(width: 16),
              Flexible(
                child: Text(
                  message,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static void _showResult(BuildContext context, Map<String, dynamic> result) {
    final total = result['total'] as int? ?? 0;
    final created = result['created'] as int? ?? 0;
    final failed = result['failed'] as int? ?? 0;
    final results = (result['results'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final errors = results.where((r) => r['success'] == false).toList();
    final allOk = failed == 0;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
          ),
          padding: const EdgeInsets.all(24),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.75,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: allOk
                      ? const Color(0xFF10B981).withValues(alpha: 0.12)
                      : const Color(0xFFF59E0B).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  allOk ? Icons.cloud_done_rounded : Icons.warning_amber_rounded,
                  color: allOk ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                  size: 28,
                ),
              ),
              const SizedBox(height: 14),
              Text('Bulk Upload Complete',
                  style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary)),
              const SizedBox(height: 16),

              // Stats row
              Row(
                children: [
                  _StatChip(label: 'Total', value: '$total', color: AppTheme.primaryBlue),
                  const SizedBox(width: 8),
                  _StatChip(label: 'Created', value: '$created', color: const Color(0xFF10B981)),
                  const SizedBox(width: 8),
                  _StatChip(label: 'Failed', value: '$failed',
                      color: failed > 0 ? const Color(0xFFEF4444) : AppTheme.textTertiary),
                ],
              ),

              // Error list (if any)
              if (errors.isNotEmpty) ...[
                const SizedBox(height: 14),
                Flexible(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.all(10),
                      itemCount: errors.length,
                      separatorBuilder: (ctx, i) => const Divider(height: 10),
                      itemBuilder: (_, i) {
                        final e = errors[i];
                        final row = e['row'] ?? i + 2;
                        final msg = e['error'] ?? 'Unknown error';
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Row $row: ',
                                style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFFEF4444))),
                            Expanded(
                              child: Text(msg.toString(),
                                  style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: const Color(0xFF991B1B))),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Done',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _msg(Object e) {
    final s = e.toString();
    return s.length > 120 ? '${s.substring(0, 120)}…' : s;
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.20)),
        ),
        child: Column(
          children: [
            Text(value,
                style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: color)),
            const SizedBox(height: 2),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color.withValues(alpha: 0.75))),
          ],
        ),
      ),
    );
  }
}
