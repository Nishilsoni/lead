import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_theme.dart';
import '../providers/auth_provider.dart';
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
      body: _screens[_currentIndex],
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
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          backgroundColor: Colors.white,
          selectedItemColor: AppTheme.primaryBlue,
          unselectedItemColor: AppTheme.textTertiary,
          selectedLabelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
          unselectedLabelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_rounded),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people_alt_rounded),
              label: 'Leads',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_rounded),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // MAIN Section
              _buildSectionHeader('MAIN'),
              _buildDrawerItem(
                context,
                icon: Icons.dashboard_rounded,
                label: 'Dashboard',
                onTap: () {
                  _setCurrentIndex(0);
                  Navigator.pop(context);
                },
              ),

              const SizedBox(height: 16),

              // SCHEDULING Section
              _buildSectionHeader('SCHEDULING'),
              _buildDrawerItem(
                context,
                icon: Icons.calendar_today_rounded,
                label: 'Calendar',
                onTap: () {
                  _showComingSoon('Calendar');
                  Navigator.pop(context);
                },
              ),
              _buildDrawerItem(
                context,
                icon: Icons.schedule_rounded,
                label: 'Appointments',
                onTap: () {
                  _showComingSoon('Appointments');
                  Navigator.pop(context);
                },
              ),

              const SizedBox(height: 16),

              // CRM Section
              _buildSectionHeader('CRM'),
              _buildDrawerItem(
                context,
                icon: Icons.rocket_launch_rounded,
                label: 'Leads',
                onTap: () {
                  _setCurrentIndex(1);
                  Navigator.pop(context);
                },
              ),
              _buildDrawerItem(
                context,
                icon: Icons.local_offer_rounded,
                label: 'Tags',
                onTap: () {
                  _showComingSoon('Tags');
                  Navigator.pop(context);
                },
              ),
              _buildExpandableItem(
                context,
                icon: Icons.campaign_rounded,
                label: 'Marketing',
                sectionKey: 'marketing',
                subsections: [
                  ('Campaigns', Icons.layers_rounded),
                  ('Facebook', Icons.facebook_rounded),
                ],
              ),

              const SizedBox(height: 16),

              // BILLING Section
              _buildSectionHeader('BILLING'),
              _buildDrawerItem(
                context,
                icon: Icons.inventory_2_rounded,
                label: 'Products/Services',
                onTap: () {
                  _showComingSoon('Products/Services');
                  Navigator.pop(context);
                },
              ),
              _buildExpandableItem(
                context,
                icon: Icons.receipt_long_rounded,
                label: 'Sales',
                sectionKey: 'sales',
                subsections: [
                  ('Customers', Icons.person_rounded),
                  ('Orders', Icons.shopping_bag_rounded),
                  ('Estimates', Icons.description_rounded),
                  ('Invoice', Icons.receipt_rounded),
                  ('Payment Receipts', Icons.payment_rounded),
                ],
              ),

              const SizedBox(height: 16),

              // TOOLS Section
              _buildSectionHeader('TOOLS'),
              _buildExpandableItem(
                context,
                icon: Icons.admin_panel_settings_rounded,
                label: 'Administration',
                sectionKey: 'administration',
                subsections: [
                  ('Users', Icons.people_rounded),
                  ('Roles', Icons.security_rounded),
                  ('Plans', Icons.layers_rounded),
                  ('User Org Access', Icons.vpn_key_rounded),
                  ('Facebook', Icons.facebook_rounded),
                  ('IndiaMart', Icons.storefront_rounded),
                  ('Shopify', Icons.shopping_cart_rounded),
                ],
              ),

              const SizedBox(height: 16),

              // ACCOUNT Section
              _buildSectionHeader('ACCOUNT'),
              _buildDrawerItem(
                context,
                icon: Icons.settings_rounded,
                label: 'Settings',
                onTap: () {
                  _setCurrentIndex(2);
                  Navigator.pop(context);
                },
              ),
              _buildDrawerItem(
                context,
                icon: Icons.logout_rounded,
                label: 'Logout',
                onTap: () {
                  _showLogoutConfirmation();
                },
                isDestructive: true,
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppTheme.textTertiary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final isSelected = _isItemSelected(label);
    final itemColor = isDestructive ? Colors.red : (isSelected ? AppTheme.primaryBlue : AppTheme.textSecondary);
    final bgColor = isSelected ? AppTheme.primaryBlue.withValues(alpha: 0.08) : Colors.transparent;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        leading: Icon(icon, color: itemColor, size: 20),
        title: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: itemColor,
          ),
        ),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        minLeadingWidth: 24,
      ),
    );
  }

  Widget _buildExpandableItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String sectionKey,
    required List<(String, IconData)> subsections,
  }) {
    final isExpanded = _expandedSections.contains(sectionKey);

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: ListTile(
            leading: Icon(icon, color: AppTheme.textSecondary, size: 20),
            title: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),
            trailing: Icon(
              isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
              color: AppTheme.textTertiary,
              size: 20,
            ),
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedSections.remove(sectionKey);
                } else {
                  _expandedSections.add(sectionKey);
                }
              });
            },
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            minLeadingWidth: 24,
          ),
        ),
        if (isExpanded)
          Padding(
            padding: const EdgeInsets.only(left: 24, top: 4, bottom: 4),
            child: Column(
              children: subsections.map((subsection) {
                final (subsectionLabel, subsectionIcon) = subsection;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListTile(
                    leading: Icon(
                      subsectionIcon,
                      color: AppTheme.textTertiary,
                      size: 18,
                    ),
                    title: Text(
                      subsectionLabel,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    onTap: () {
                      _showComingSoon(subsectionLabel);
                      Navigator.pop(context);
                    },
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    minLeadingWidth: 24,
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  bool _isItemSelected(String label) {
    return (_currentIndex == 0 && label == 'Dashboard') ||
        (_currentIndex == 1 && label == 'Leads') ||
        (_currentIndex == 2 && label == 'Settings');
  }

  void _setCurrentIndex(int index) {
    setState(() {
      _currentIndex = index;
    });
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
              // Icon
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
              // Buttons
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
}
