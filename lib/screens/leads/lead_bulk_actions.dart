import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/app_theme.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../services/lead_service.dart';

/// Export flow for leads, shared by the Leads screen menu.
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

  static String _msg(Object e) {
    final s = e.toString();
    return s.length > 120 ? '${s.substring(0, 120)}…' : s;
  }
}
