import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_theme.dart';

/// Compact filled "Add" button placed in the admin screens' AppBar — mirrors
/// the web's top-right "Add new user" / "Create Role" action and keeps the
/// bottom area free for the pagination bar.
class AdminAddButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final IconData icon;

  const AdminAddButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon = Icons.add_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.primaryBlue,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
