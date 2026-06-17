import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_theme.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../models/lead.dart';
import '../../providers/lead_provider.dart';
import '../widgets/empty_state.dart';
import '../widgets/lead_card.dart';
import '../widgets/shimmer_loading.dart';
import 'lead_detail_screen.dart';
import 'lead_form_screen.dart';

/// Main lead listing screen with search, filter, pagination, and CRUD actions.
class LeadListScreen extends StatefulWidget {
  const LeadListScreen({super.key});

  @override
  State<LeadListScreen> createState() => _LeadListScreenState();
}

class _LeadListScreenState extends State<LeadListScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  Timer? _autoRefreshTimer;
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<LeadProvider>();
      provider.loadLeads();
      provider.loadSupportingData();
    });
    _autoRefreshTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (mounted) context.read<LeadProvider>().loadLeads();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<LeadProvider>().loadMore();
    }
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      context.read<LeadProvider>().search(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // ── Stage Filter Chips ────────────────────────────────
          _buildStageFilters(),

          // ── Lead List ─────────────────────────────────────────
          Expanded(child: _buildLeadList()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToForm(context),
        icon: const Icon(Icons.add_rounded),
        label: Text(
          'New Lead',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      leading: IconButton(
        icon: const Icon(Icons.menu_rounded, color: AppTheme.textPrimary),
        onPressed: () => Scaffold.of(context).openDrawer(),
      ),
      title: _showSearch
          ? TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search leads...',
                hintStyle: GoogleFonts.inter(
                  color: AppTheme.textTertiary,
                  fontSize: 16,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
              ),
              style: GoogleFonts.inter(
                fontSize: 16,
                color: AppTheme.textPrimary,
              ),
            )
          : Row(
              children: [
                Text(
                  'Leads',
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                Consumer<LeadProvider>(
                  builder: (context, provider, child) {
                    if (provider.totalCount > 0) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${provider.totalCount}',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
      actions: [
        IconButton(
          icon: Icon(
            _showSearch ? Icons.close_rounded : Icons.search_rounded,
            color: AppTheme.textSecondary,
          ),
          onPressed: () {
            setState(() {
              _showSearch = !_showSearch;
              if (!_showSearch) {
                _searchController.clear();
                context.read<LeadProvider>().search('');
              }
            });
          },
        ),
      ],
      bottom: _showSearch
          ? null
          : PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(
                height: 1,
                color: const Color(0xFFE5E7EB),
              ),
            ),
    );
  }

  Widget _buildStageFilters() {
    return Consumer<LeadProvider>(
      builder: (context, provider, _) {
        if (provider.stages.isEmpty) return const SizedBox.shrink();

        return Container(
          color: Colors.white,
          child: Column(
            children: [
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    // "All" chip
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 8,
                      ),
                      child: FilterChip(
                        label: Text(
                          'All',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: provider.selectedStage == null
                                ? Colors.white
                                : AppTheme.textSecondary,
                          ),
                        ),
                        selected: provider.selectedStage == null,
                        onSelected: (_) => provider.filterByStage(null),
                        selectedColor: AppTheme.primaryBlue,
                        checkmarkColor: Colors.white,
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: provider.selectedStage == null
                                ? AppTheme.primaryBlue
                                : const Color(0xFFF3F4F6),
                            width: 1.5,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),

                    // Stage chips
                    ...provider.stages.map((stage) {
                      final isSelected =
                          provider.selectedStage == stage.stage;
                      final stageColor =
                          AppTheme.stageColor(stage.stage);
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 8,
                        ),
                        child: FilterChip(
                          label: Text(
                            stage.stage,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isSelected
                                  ? stageColor
                                  : AppTheme.textSecondary,
                            ),
                          ),
                          selected: isSelected,
                          onSelected: (_) =>
                              provider.filterByStage(stage.stage),
                          selectedColor:
                              stageColor.withValues(alpha: 0.12),
                          checkmarkColor: stageColor,
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: isSelected
                                  ? stageColor.withValues(alpha: 0.5)
                                  : const Color(0xFFF3F4F6),
                              width: 1.5,
                            ),
                          ),
                          padding:
                              const EdgeInsets.symmetric(horizontal: 4),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                      );
                    }),
                  ],
                ),
              ),
              Container(height: 1, color: const Color(0xFFE5E7EB)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLeadList() {
    return Consumer<LeadProvider>(
      builder: (context, provider, _) {
        // Loading state
        if (provider.isLoading) {
          return const ShimmerLoading();
        }

        // Error state
        if (provider.error != null && provider.leads.isEmpty) {
          return EmptyState(
            title: 'Something went wrong',
            subtitle: provider.error!,
            icon: Icons.error_outline_rounded,
            actionLabel: 'Retry',
            onAction: () => provider.loadLeads(refresh: true),
          );
        }

        // Empty state
        if (provider.leads.isEmpty) {
          return EmptyState(
            title: provider.searchQuery.isNotEmpty ||
                    provider.selectedStage != null
                ? 'No matching leads'
                : 'No leads yet',
            subtitle: provider.searchQuery.isNotEmpty ||
                    provider.selectedStage != null
                ? 'Try adjusting your search or filters'
                : 'Tap + to create your first lead',
            icon: provider.searchQuery.isNotEmpty
                ? Icons.search_off_rounded
                : Icons.people_outline_rounded,
            actionLabel: provider.searchQuery.isNotEmpty ||
                    provider.selectedStage != null
                ? 'Clear Filters'
                : null,
            onAction: provider.searchQuery.isNotEmpty ||
                    provider.selectedStage != null
                ? () => provider.clearFilters()
                : null,
          );
        }

        // Lead list
        return RefreshIndicator(
          onRefresh: () => provider.loadLeads(refresh: true),
          color: AppTheme.primaryBlue,
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.only(top: 8, bottom: 80),
            itemCount: provider.leads.length + (provider.hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == provider.leads.length) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  ),
                );
              }

              final lead = provider.leads[index];
              return LeadCard(
                lead: lead,
                onTap: () => _navigateToDetail(context, lead),
                onMarkWon: () => _confirmStageChange(context, lead, won: true),
                onMarkLost: () => _confirmStageChange(context, lead, won: false),
              );
            },
          ),
        );
      },
    );
  }

  void _navigateToDetail(BuildContext context, Lead lead) {
    final provider = context.read<LeadProvider>();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LeadDetailScreen(lead: lead),
      ),
    ).then((_) {
      // Refresh list when returning from detail (may have edited/deleted)
      provider.loadLeads(refresh: true);
    });
  }

  void _navigateToForm(BuildContext context, {Lead? lead}) {
    final provider = context.read<LeadProvider>();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LeadFormScreen(lead: lead),
      ),
    ).then((result) {
      if (result == true) {
        provider.loadLeads(refresh: true);
      }
    });
  }

  /// Modern confirmation dialog for marking a lead Won / Lost via swipe.
  void _confirmStageChange(BuildContext context, Lead lead,
      {required bool won}) {
    final Color accent =
        won ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    final Color accentDark =
        won ? const Color(0xFF059669) : const Color(0xFFDC2626);
    final IconData icon =
        won ? Icons.emoji_events_rounded : Icons.do_not_disturb_on_rounded;
    final String title = won ? 'Mark as Won' : 'Mark as Lost';
    final String message = won
        ? 'Move this lead to the Won stage? This marks the deal as successfully closed.'
        : 'Move this lead to the Lost stage? This marks the deal as closed without a win.';

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Gradient icon
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [accent, accentDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 34),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 10),
              // Lead name chip
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  lead.displayName,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF334155),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF6B7280),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 26),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF374151),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _applyStageChange(context, lead, won: won);
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _applyStageChange(BuildContext context, Lead lead,
      {required bool won}) async {
    final provider = context.read<LeadProvider>();
    final stage = won ? provider.wonStageName : provider.lostStageName;
    try {
      await provider.setLeadStage(lead, stage);
      if (context.mounted) {
        SnackbarHelper.showSuccess(
          context,
          won ? 'Lead marked as Won 🎉' : 'Lead marked as Lost',
        );
      }
    } catch (e) {
      if (context.mounted) {
        SnackbarHelper.showError(context, e.toString());
      }
    }
  }
}
