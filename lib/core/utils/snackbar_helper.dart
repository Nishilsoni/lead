import 'package:flutter/material.dart';

/// Helper class for showing consistent snackbar messages.
class SnackbarHelper {
  SnackbarHelper._();

  static void showSuccess(BuildContext context, String message) {
    _show(context, message, const Color(0xFF10B981), Icons.check_circle_rounded);
  }

  static void showError(BuildContext context, String message) {
    _show(context, message, const Color(0xFFEF4444), Icons.error_rounded);
  }

  static void showErrorOnMessenger(
      ScaffoldMessengerState messenger, String message) {
    _showOnMessenger(
        messenger, message, const Color(0xFFEF4444), Icons.error_rounded);
  }

  static void showInfo(BuildContext context, String message) {
    _show(context, message, const Color(0xFF3B82F6), Icons.info_rounded);
  }

  static void _showOnMessenger(
    ScaffoldMessengerState messenger,
    String message,
    Color color,
    IconData icon,
  ) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(_buildSnackBar(message, color, icon));
  }

  static void _show(
    BuildContext context,
    String message,
    Color color,
    IconData icon,
  ) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(_buildSnackBar(message, color, icon));
  }

  static SnackBar _buildSnackBar(String message, Color color, IconData icon) {
    return SnackBar(
      content: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 3),
    );
  }
}
