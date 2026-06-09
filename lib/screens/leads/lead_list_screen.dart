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
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
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
                onEdit: () => _navigateToForm(context, lead: lead),
                onDelete: () => _confirmDelete(context, lead),
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

  void _confirmDelete(BuildContext context, Lead lead) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Delete Lead',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to delete "${lead.displayName}"? This action cannot be undone.',
          style: GoogleFonts.inter(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: AppTheme.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await context.read<LeadProvider>().deleteLead(lead.id);
                if (context.mounted) {
                  SnackbarHelper.showSuccess(context, 'Lead deleted');
                }
              } catch (e) {
                if (context.mounted) {
                  SnackbarHelper.showError(context, e.toString());
                }
              }
            },
            child: Text(
              'Delete',
              style: GoogleFonts.inter(
                color: const Color(0xFFEF4444),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

}
