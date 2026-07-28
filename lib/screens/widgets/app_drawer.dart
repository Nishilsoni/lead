import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/config/environment_service.dart';
import '../../core/constants/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/lead_provider.dart';
import '../appointments/appointments_screen.dart';
import '../calendar/calendar_screen.dart';
import '../main_navigation_screen.dart';
import '../marketing/facebook_auto_import_screen.dart';
import '../marketing/facebook_integration_screen.dart';
import '../marketing/marketing_management_screen.dart';
import '../settings/stage_pipeline_screen.dart';
import '../tags/tags_screen.dart';

/// The app's single navigation drawer — shared by [MainNavigationScreen] and
/// every screen reachable from it. Attaching this as a screen's own
/// `Scaffold.drawer` is deliberate: whenever a Scaffold has a drawer, Flutter
/// automatically shows the menu icon in its AppBar instead of a back arrow
/// (see [AppBar]'s leading-resolution logic), so every destination reads as a
/// menu item rather than a page you drilled into.
///
/// Navigating anywhere from here always collapses the route stack back down
/// to the app's root first (a no-op if already there), so the stack never
/// grows past one screen deep from Main — tapping the drawer never leaves a
/// trail of stacked destinations behind it.
class AppDrawer extends StatefulWidget {
  /// Highlights the matching main-tab row. Only meaningful when this drawer
  /// is attached to [MainNavigationScreen] itself; leave null on every other
  /// screen so nothing is shown as selected.
  final int? selectedTabIndex;

  const AppDrawer({super.key, this.selectedTabIndex});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  final Set<String> _expandedSections = {};

  // ── Navigation helpers ───────────────────────────────────────────

  /// Closes the drawer, collapses back to the app root (no-op if already
  /// there), then switches the main bottom-nav tab.
  void _goToTab(int index) {
    Navigator.pop(context);
    Navigator.of(context).popUntil((route) => route.isFirst);
    MainNavigationScreen.goToTab(index);
  }

  /// Closes the drawer, collapses back to the app root (no-op if already
  /// there), then pushes [screen] fresh — so the stack is always at most one
  /// screen deep from Main.
  void _openScreen(Widget screen) {
    Navigator.pop(context);
    Navigator.of(context).popUntil((route) => route.isFirst);
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  void _onSubItemTap(String section, String label) {
    // Facebook appears in two sections and opens a different screen in each:
    //  • Marketing → "Ad Accounts" (campaign data)
    //  • Administration → "Auto Import Accounts" (page/lead-form lead import)
    if (label == 'Facebook') {
      _openScreen(section == 'administration'
          ? const FacebookAutoImportScreen()
          : const FacebookIntegrationScreen());
      return;
    }

    switch (label) {
      case 'Stage Pipeline':
        _openScreen(const StagePipelineScreen());
      case 'Campaigns':
        _openScreen(const MarketingManagementScreen());
      default:
        Navigator.pop(context);
        _showComingSoon(label);
    }
  }

  void _showComingSoon(String featureName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$featureName coming soon!'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.primaryBlue,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showLogoutConfirmation() {
    Navigator.pop(context); // close the drawer
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
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 32,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: Color(0xFFEF4444),
                  size: 28,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Logout',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You will be returned to the login screen. Any unsaved changes will be lost.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF6B7280),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
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
                        // Collapse back to root first (no-op if already there)
                        // so AuthGate's LoginScreen is what's left visible —
                        // otherwise a pushed screen would still be on top of
                        // the stack after logging out.
                        Navigator.of(context)
                            .popUntil((route) => route.isFirst);
                        context.read<LeadProvider>().clearCache();
                        context.read<AuthProvider>().logout();
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        backgroundColor: const Color(0xFFEF4444),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Logout',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
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

  // ── Build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFFFAFBFD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildDrawerHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),

                  // MAIN
                  _buildNavSection('MAIN'),
                  _buildNavItem(
                    icon: Icons.dashboard_rounded,
                    label: 'Dashboard',
                    isSelected: widget.selectedTabIndex == 0,
                    onTap: () => _goToTab(0),
                  ),

                  _buildNavDivider(),

                  // SCHEDULING
                  _buildNavSection('SCHEDULING'),
                  _buildNavItem(
                    icon: Icons.calendar_today_rounded,
                    label: 'Calendar',
                    onTap: () => _openScreen(const CalendarScreen()),
                  ),
                  _buildNavItem(
                    icon: Icons.schedule_rounded,
                    label: 'Appointments',
                    onTap: () => _openScreen(const AppointmentsScreen()),
                  ),

                  _buildNavDivider(),

                  // CRM
                  _buildNavSection('CRM'),
                  _buildNavItem(
                    icon: Icons.rocket_launch_rounded,
                    label: 'Leads',
                    isSelected: widget.selectedTabIndex == 1,
                    onTap: () => _goToTab(1),
                  ),
                  _buildNavItem(
                    icon: Icons.local_offer_rounded,
                    label: 'Tags',
                    onTap: () => _openScreen(const TagsScreen()),
                  ),
                  _buildExpandableNavItem(
                    icon: Icons.campaign_rounded,
                    label: 'Marketing',
                    sectionKey: 'marketing',
                    subsections: const [
                      (Icons.layers_rounded, 'Campaigns'),
                      (Icons.facebook_rounded, 'Facebook'),
                    ],
                  ),

                  _buildNavDivider(),

                  // ── BILLING (Products/Services + Sales) ───────────────
                  // TEMPORARILY DISABLED: these modules are not built yet.
                  // Keeping the code (commented) so it can be re-enabled later.
                  // // BILLING
                  // _buildNavSection('BILLING'),
                  // _buildNavItem(
                  //   icon: Icons.inventory_2_rounded,
                  //   label: 'Products/Services',
                  //   onTap: () => _showComingSoon('Products/Services'),
                  // ),
                  // _buildExpandableNavItem(
                  //   icon: Icons.receipt_long_rounded,
                  //   label: 'Sales',
                  //   sectionKey: 'sales',
                  //   subsections: const [
                  //     (Icons.person_rounded, 'Customers'),
                  //     (Icons.shopping_bag_rounded, 'Orders'),
                  //     (Icons.description_rounded, 'Estimates'),
                  //     (Icons.receipt_rounded, 'Invoice'),
                  //     (Icons.payment_rounded, 'Payment Receipts'),
                  //   ],
                  // ),
                  //
                  // _buildNavDivider(),

                  // TOOLS
                  _buildNavSection('TOOLS'),
                  _buildExpandableNavItem(
                    icon: Icons.admin_panel_settings_rounded,
                    label: 'Administration',
                    sectionKey: 'administration',
                    subsections: const [
                      // TEMPORARILY DISABLED: not built yet — re-enable later.
                      // (Icons.people_rounded, 'Users'),
                      // (Icons.security_rounded, 'Roles'),
                      (Icons.account_tree_rounded, 'Stage Pipeline'),
                      // (Icons.layers_rounded, 'Plans'),
                      // (Icons.vpn_key_rounded, 'User Org Access'),
                      (Icons.facebook_rounded, 'Facebook'),
                      // (Icons.storefront_rounded, 'IndiaMart'),
                      // (Icons.shopping_cart_rounded, 'Shopify'),
                    ],
                  ),

                  _buildNavDivider(),

                  // ACCOUNT
                  _buildNavSection('ACCOUNT'),
                  _buildNavItem(
                    icon: Icons.settings_rounded,
                    label: 'Settings',
                    isSelected: widget.selectedTabIndex == 2,
                    onTap: () => _goToTab(2),
                  ),
                  _buildNavItem(
                    icon: Icons.logout_rounded,
                    label: 'Logout',
                    isDestructive: true,
                    onTap: _showLogoutConfirmation,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Drawer Header ─────────────────────────────────────────────────

  Widget _buildDrawerHeader() {
    return ListenableBuilder(
      listenable: EnvironmentService.instance,
      builder: (context, _) {
        final env = EnvironmentService.instance;
        final orgId = env.activeOrgId;
        String orgName = 'OceanCRM';
        if (orgId != null && env.orgList.isNotEmpty) {
          try {
            orgName = env.orgList.firstWhere((o) => o.id == orgId).name;
          } catch (_) {
            orgName = env.orgList.first.name;
          }
        }

        return Container(
          color: Colors.white,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // App logo
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(13),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryBlue.withValues(
                                alpha: 0.28,
                              ),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(13),
                          child: Image.asset(
                            'assets/icon.png',
                            width: 46,
                            height: 46,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'OceanCRM',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF10B981),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    orgName,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: AppTheme.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(height: 1, color: const Color(0xFFF1F5F9)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Nav Building Blocks ───────────────────────────────────────────

  Widget _buildNavSection(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF94A3B8),
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildNavDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Container(height: 1, color: const Color(0xFFF1F5F9)),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isSelected = false,
    bool isDestructive = false,
  }) {
    final Color accent = isDestructive
        ? const Color(0xFFEF4444)
        : AppTheme.primaryBlue;
    final Color iconColor = isDestructive
        ? const Color(0xFFEF4444)
        : (isSelected ? AppTheme.primaryBlue : const Color(0xFF64748B));
    final Color textColor = isDestructive
        ? const Color(0xFFEF4444)
        : (isSelected ? AppTheme.primaryBlue : const Color(0xFF374151));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
      child: Material(
        color: isSelected
            ? AppTheme.primaryBlue.withValues(alpha: 0.06)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          splashColor: accent.withValues(alpha: 0.08),
          highlightColor: accent.withValues(alpha: 0.04),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: isSelected
                  ? Border(left: BorderSide(color: accent, width: 3))
                  : null,
            ),
            padding: EdgeInsets.only(
              left: isSelected ? 10 : 13,
              right: 13,
              top: 10,
              bottom: 10,
            ),
            child: Row(
              children: [
                Icon(icon, color: iconColor, size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandableNavItem({
    required IconData icon,
    required String label,
    required String sectionKey,
    required List<(IconData, String)> subsections,
  }) {
    final isExpanded = _expandedSections.contains(sectionKey);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Parent row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: () {
                setState(() {
                  if (isExpanded) {
                    _expandedSections.remove(sectionKey);
                  } else {
                    _expandedSections.add(sectionKey);
                  }
                });
              },
              borderRadius: BorderRadius.circular(10),
              splashColor: AppTheme.primaryBlue.withValues(alpha: 0.06),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Icon(icon, color: const Color(0xFF64748B), size: 18),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        label,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF374151),
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Color(0xFF94A3B8),
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Sub-items
        if (isExpanded)
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 2),
            child: Column(
              children: subsections.map((item) {
                final (itemIcon, itemLabel) = item;
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 1,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: () => _onSubItemTap(sectionKey, itemLabel),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 4,
                              height: 4,
                              decoration: const BoxDecoration(
                                color: Color(0xFFCBD5E1),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Icon(
                              itemIcon,
                              color: const Color(0xFF94A3B8),
                              size: 15,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                itemLabel,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                  color: const Color(0xFF6B7280),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}
