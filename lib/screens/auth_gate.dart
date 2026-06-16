import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/network/api_client.dart';
import '../providers/auth_provider.dart';
import '../providers/lead_provider.dart';
import 'main_navigation_screen.dart';
import 'login/login_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
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
    ApiClient.onUnauthorized = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.isAuthenticated) return const MainNavigationScreen();
        return const LoginScreen();
      },
    );
  }
}
