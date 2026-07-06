import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/network/api_client.dart';
import '../models/plan.dart';
import '../providers/auth_provider.dart';
import '../providers/lead_provider.dart';
import '../services/plan_service.dart';
import 'billing/plan_expired_screen.dart';
import 'main_navigation_screen.dart';
import 'login/login_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> with WidgetsBindingObserver {
  final PlanService _planService = PlanService();

  Plan? _plan;
  bool _planChecked = false; // first check completed (so we know expiry)
  bool _checking = false;
  bool _wasAuthenticated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // When token refresh fails the interceptor calls this, which logs the
    // user out and lets the Consumer below rebuild to LoginScreen.
    ApiClient.onUnauthorized = () {
      if (mounted) {
        context.read<LeadProvider>().clearCache();
        context.read<AuthProvider>().logout();
      }
    };
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ApiClient.onUnauthorized = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-check on resume so a plan that lapses mid-session is caught.
    if (state == AppLifecycleState.resumed &&
        context.read<AuthProvider>().isAuthenticated) {
      _checkPlan();
    }
  }

  /// Fetch the current plan. FAILS OPEN: on any error we leave [_plan] as-is /
  /// null so the user is never locked out by a network/parse problem.
  Future<void> _checkPlan() async {
    if (_checking) return;
    _checking = true;
    try {
      final plan = await _planService.fetchPlan();
      if (!mounted) return;
      if (plan != null) {
        setState(() {
          _plan = plan;
          _planChecked = true;
        });
      } else {
        _planChecked = true;
      }
    } catch (_) {
      // ignore — fail open
    } finally {
      _checking = false;
    }
  }

  void _resetPlanState() {
    _plan = null;
    _planChecked = false;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (!auth.isAuthenticated) {
          // Clear plan state on logout so the next login re-checks fresh.
          if (_wasAuthenticated) {
            _wasAuthenticated = false;
            _resetPlanState();
          }
          return const LoginScreen();
        }

        // Just became authenticated → kick off the first plan check.
        if (!_wasAuthenticated) {
          _wasAuthenticated = true;
          WidgetsBinding.instance.addPostFrameCallback((_) => _checkPlan());
        }

        // Expired → hard paywall. (Only blocks once we have a confirmed
        // expired plan; while unknown we optimistically show the CRM.)
        if (_planChecked && _plan != null && _plan!.isExpired) {
          return const PlanExpiredScreen();
        }

        return const MainNavigationScreen();
      },
    );
  }
}
