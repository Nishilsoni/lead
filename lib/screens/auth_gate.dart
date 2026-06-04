import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'main_navigation_screen.dart';
import 'login/login_screen.dart';

/// Reactively switches between [LoginScreen] and [MainNavigationScreen]
/// based on [AuthProvider.isAuthenticated]. Any login or logout calls
/// [notifyListeners] on [AuthProvider], which causes this widget to rebuild
/// and immediately show the correct screen.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

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
