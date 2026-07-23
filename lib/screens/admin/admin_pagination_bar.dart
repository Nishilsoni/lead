import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_theme.dart';

/// Footer pager shared by the Users and Roles admin lists.
///
/// The list endpoints return every record at once, so paging is done
/// client-side: the screen slices its filtered list into [pageSize]-sized pages
/// and this bar drives which page is shown. Mirrors the web's
/// "N items in total  ‹ 1 ›" footer.
class AdminPaginationBar extends StatelessWidget {
  final int totalItems;
  final int pageSize;
  final int currentPage; // 1-based
  final String unitLabel; // e.g. 'user', 'role'
  final ValueChanged<int> onPageChanged;

  const AdminPaginationBar({
    super.key,
    required this.totalItems,
    required this.currentPage,
    required this.unitLabel,
    required this.onPageChanged,
    this.pageSize = 10,
  });

  int get pageCount => totalItems <= 0 ? 1 : ((totalItems - 1) ~/ pageSize) + 1;

  /// Windowed list of page numbers to show (max 5), keeping the current page
  /// centred when possible.
  List<int> get _visiblePages {
    final count = pageCount;
    if (count <= 5) {
      return [for (var i = 1; i <= count; i++) i];
    }
    var start = currentPage - 2;
    var end = currentPage + 2;
    if (start < 1) {
      end += 1 - start;
      start = 1;
    }
    if (end > count) {
      start -= end - count;
      end = count;
    }
    if (start < 1) start = 1;
    return [for (var i = start; i <= end; i++) i];
  }

  @override
  Widget build(BuildContext context) {
    final pages = _visiblePages;
    final unit = totalItems == 1 ? unitLabel : '${unitLabel}s';

    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 10, 16, 10 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Text(
            '$totalItems $unit in total',
            style: GoogleFonts.inter(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
          const Spacer(),
          _arrow(
            icon: Icons.chevron_left_rounded,
            enabled: currentPage > 1,
            onTap: () => onPageChanged(currentPage - 1),
          ),
          const SizedBox(width: 4),
          for (final p in pages) ...[
            _pageButton(p),
            const SizedBox(width: 4),
          ],
          _arrow(
            icon: Icons.chevron_right_rounded,
            enabled: currentPage < pageCount,
            onTap: () => onPageChanged(currentPage + 1),
          ),
        ],
      ),
    );
  }

  Widget _pageButton(int page) {
    final selected = page == currentPage;
    return InkWell(
      onTap: selected ? null : () => onPageChanged(page),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryBlue : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? AppTheme.primaryBlue
                : const Color(0xFFE5E7EB),
          ),
        ),
        child: Text(
          '$page',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _arrow({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Icon(
          icon,
          size: 20,
          color: enabled ? AppTheme.textSecondary : AppTheme.textTertiary,
        ),
      ),
    );
  }
}
