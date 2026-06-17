import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/config/environment_service.dart';
import '../core/constants/app_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/lead_provider.dart';
import 'calendar/calendar_screen.dart';
import 'dashboard/dashboard_screen.dart';
import 'leads/lead_list_screen.dart';
import 'settings/settings_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  final Set<String> _expandedSections = {};

  final List<Widget> _screens = const [
    DashboardScreen(),
    LeadListScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _buildDrawer(),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: Colors.white,
          selectedItemColor: AppTheme.primaryBlue,
          unselectedItemColor: AppTheme.textTertiary,
          selectedLabelStyle:
              GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
          unselectedLabelStyle:
              GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
                icon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
            BottomNavigationBarItem(
                icon: Icon(Icons.people_alt_rounded), label: 'Leads'),
            BottomNavigationBarItem(
                icon: Icon(Icons.settings_rounded), label: 'Settings'),
          ],
        ),
      ),
    );
  }

  // ── Drawer ────────────────────────────────────────────────────────

  Widget _buildDrawer() {
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
                    isSelected: _currentIndex == 0,
                    onTap: () {
                      _setCurrentIndex(0);
                      Navigator.pop(context);
                    },
                  ),

                  _buildNavDivider(),

                  // SCHEDULING
                  _buildNavSection('SCHEDULING'),
                  _buildNavItem(
                    icon: Icons.calendar_today_rounded,
                    label: 'Calendar',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const CalendarScreen()),
                      );
                    },
                  ),
                  _buildNavItem(
                    icon: Icons.schedule_rounded,
                    label: 'Appointments',
                    onTap: () {
                      _showComingSoon('Appointments');
                      Navigator.pop(context);
                    },
                  ),

                  _buildNavDivider(),

                  // CRM
                  _buildNavSection('CRM'),
                  _buildNavItem(
                    icon: Icons.rocket_launch_rounded,
                    label: 'Leads',
                    isSelected: _currentIndex == 1,
                    onTap: () {
                      _setCurrentIndex(1);
                      Navigator.pop(context);
                    },
                  ),
                  _buildNavItem(
                    icon: Icons.local_offer_rounded,
                    label: 'Tags',
                    onTap: () {
                      _showComingSoon('Tags');
                      Navigator.pop(context);
                    },
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

                  // BILLING
                  _buildNavSection('BILLING'),
                  _buildNavItem(
                    icon: Icons.inventory_2_rounded,
                    label: 'Products/Services',
                    onTap: () {
                      _showComingSoon('Products/Services');
                      Navigator.pop(context);
                    },
                  ),
                  _buildExpandableNavItem(
                    icon: Icons.receipt_long_rounded,
                    label: 'Sales',
                    sectionKey: 'sales',
                    subsections: const [
                      (Icons.person_rounded, 'Customers'),
                      (Icons.shopping_bag_rounded, 'Orders'),
                      (Icons.description_rounded, 'Estimates'),
                      (Icons.receipt_rounded, 'Invoice'),
                      (Icons.payment_rounded, 'Payment Receipts'),
                    ],
                  ),

                  _buildNavDivider(),

                  // TOOLS
                  _buildNavSection('TOOLS'),
                  _buildExpandableNavItem(
                    icon: Icons.admin_panel_settings_rounded,
                    label: 'Administration',
                    sectionKey: 'administration',
                    subsections: const [
                      (Icons.people_rounded, 'Users'),
                      (Icons.security_rounded, 'Roles'),
                      (Icons.layers_rounded, 'Plans'),
                      (Icons.vpn_key_rounded, 'User Org Access'),
                      (Icons.facebook_rounded, 'Facebook'),
                      (Icons.storefront_rounded, 'IndiaMart'),
                      (Icons.shopping_cart_rounded, 'Shopify'),
                    ],
                  ),

                  _buildNavDivider(),

                  // ACCOUNT
                  _buildNavSection('ACCOUNT'),
                  _buildNavItem(
                    icon: Icons.settings_rounded,
                    label: 'Settings',
                    isSelected: _currentIndex == 2,
                    onTap: () {
                      _setCurrentIndex(2);
                      Navigator.pop(context);
                    },
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
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.primaryBlue,
                              AppTheme.primaryBlue.withValues(alpha: 0.72),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(13),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryBlue.withValues(alpha: 0.28),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            'O',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
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
    final Color accent =
        isDestructive ? const Color(0xFFEF4444) : AppTheme.primaryBlue;
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
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: () {
                        _showComingSoon(itemLabel);
                        Navigator.pop(context);
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
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
                            Icon(itemIcon,
                                color: const Color(0xFF94A3B8), size: 15),
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

  // ── Helpers ───────────────────────────────────────────────────────

  void _setCurrentIndex(int index) {
    setState(() => _currentIndex = index);
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
    Navigator.pop(context);
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
                child: const Icon(Icons.logout_rounded,
                    color: Color(0xFFEF4444), size: 28),
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
                            borderRadius: BorderRadius.circular(12)),
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
                        context.read<LeadProvider>().clearCache();
                        context.read<AuthProvider>().logout();
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        backgroundColor: const Color(0xFFEF4444),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        'Logout',
                        style: GoogleFonts.inter(
                            fontSize: 14, fontWeight: FontWeight.w600),
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
}
