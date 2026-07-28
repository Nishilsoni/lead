import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_theme.dart';

/// Footer pager shared by every paginated list screen (Users, Roles, Leads).
///
/// Works equally well whether the caller paginates client-side (slicing an
/// already-fully-loaded list, as the admin screens do) or server-side
/// (fetching one page at a time, as the leads list does) — it only needs to
/// know the total item count and current page. Mirrors the web's
/// "N items in total  ‹ 1 ›" footer.
class PaginationBar extends StatelessWidget {
  final int totalItems;
  final int pageSize;
  final int currentPage; // 1-based
  final String unitLabel; // e.g. 'user', 'role', 'lead'
  final ValueChanged<int> onPageChanged;

  /// When true, page controls are disabled — used while a server-side page
  /// fetch is in flight so a second tap can't fire mid-request.
  final bool isLoading;

  const PaginationBar({
    super.key,
    required this.totalItems,
    required this.currentPage,
    required this.unitLabel,
    required this.onPageChanged,
    this.pageSize = 10,
    this.isLoading = false,
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
            enabled: currentPage > 1 && !isLoading,
            onTap: () => onPageChanged(currentPage - 1),
          ),
          const SizedBox(width: 4),
          for (final p in pages) ...[
            _pageButton(p),
            const SizedBox(width: 4),
          ],
          _arrow(
            icon: Icons.chevron_right_rounded,
            enabled: currentPage < pageCount && !isLoading,
            onTap: () => onPageChanged(currentPage + 1),
          ),
        ],
      ),
    );
  }

  Widget _pageButton(int page) {
    final selected = page == currentPage;
    final tappable = !selected && !isLoading;
    return InkWell(
      onTap: tappable ? () => onPageChanged(page) : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        // maxHeight is required alongside alignment: without it, Container
        // wraps its child in Align, which EXPANDS to fill any bounded parent
        // (e.g. Scaffold.bottomNavigationBar's loose-but-bounded height) —
        // an open-ended minHeight alone doesn't stop that expansion.
        constraints:
            const BoxConstraints(minWidth: 32, minHeight: 32, maxHeight: 32),
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
