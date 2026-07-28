import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants/app_theme.dart';
import 'dashboard/dashboard_screen.dart';
import 'leads/lead_list_screen.dart';
import 'settings/settings_screen.dart';
import 'widgets/app_drawer.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  /// Lets pushed screens (e.g. Tags) switch the active bottom-nav tab.
  /// Dashboard = 0, Leads = 1, Settings = 2.
  static void Function(int index)? _tabSwitcher;
  static void goToTab(int index) => _tabSwitcher?.call(index);

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    MainNavigationScreen._tabSwitcher = _setCurrentIndex;
  }

  @override
  void dispose() {
    if (MainNavigationScreen._tabSwitcher == _setCurrentIndex) {
      MainNavigationScreen._tabSwitcher = null;
    }
    super.dispose();
  }

  final List<Widget> _screens = const [
    DashboardScreen(),
    LeadListScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: AppDrawer(selectedTabIndex: _currentIndex),
      body: IndexedStack(index: _currentIndex, children: _screens),
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
          selectedLabelStyle: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
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

  void _setCurrentIndex(int index) {
    setState(() => _currentIndex = index);
  }
}
