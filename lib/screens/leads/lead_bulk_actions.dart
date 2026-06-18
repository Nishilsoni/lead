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
    _showProgress(context, 'Preparing export…');
    try {
      final bytes = await _service.exportLeads();
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();

      if (bytes.isEmpty) {
        if (context.mounted) {
          SnackbarHelper.showError(context, 'Export returned no data');
        }
        return;
      }

      // Write to a temp file, then open the native share sheet so the user can
      // save to Files / Drive / email on both iOS and Android.
      final filename =
          'leads_${DateTime.now().toIso8601String().split('T').first}.xlsx';
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(bytes, flush: true);

      await Share.shareXFiles(
        [XFile(file.path, name: filename, mimeType: _xlsxMime)],
        subject: 'Leads export',
        text: 'Leads export',
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        SnackbarHelper.showError(context, 'Export failed: ${_msg(e)}');
      }
    }
  }

  static const String _xlsxMime =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

  // ── Bulk Upload ───────────────────────────────────────────────────────────────

  /// Returns true if any leads were uploaded (so the caller can refresh).
  static Future<bool> bulkUpload(BuildContext context) async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls', 'csv'],
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
    _showProgress(context, 'Uploading ${file.name}…');
    try {
      final result = await _service.bulkUploadLeads(
        bytes: bytes,
        filename: file.name,
      );
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      if (context.mounted) _showResult(context, result);
      return true;
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
    final created = result['created'] ?? result['success'] ?? result['inserted'];
    final failed = result['failed'] ?? result['errors'] ?? result['skipped'];
    final message = result['message']?.toString();

    final lines = <String>[];
    if (created != null) lines.add('Created: $created');
    if (failed != null) lines.add('Failed: $failed');
    if (lines.isEmpty && message != null) lines.add(message);
    if (lines.isEmpty) lines.add('Upload complete');

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.cloud_done_rounded,
                    color: Color(0xFF10B981), size: 28),
              ),
              const SizedBox(height: 16),
              Text('Bulk Upload',
                  style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary)),
              const SizedBox(height: 10),
              ...lines.map((l) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(l,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                            fontSize: 14, color: AppTheme.textSecondary)),
                  )),
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
