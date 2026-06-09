import 'package:flutter/material.dart';
import '../models/auth.dart';
import '../services/auth_service.dart';

/// Manages authentication state across the application.
class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  bool _isAuthenticated = false;
  String? _error;

  bool get isLoading => _isLoading;
  bool get isAuthenticated => _isAuthenticated;
  String? get error => _error;

  /// Check if user has saved auth tokens on app startup.
  Future<void> checkAuthStatus() async {
    _isAuthenticated = await _authService.isAuthenticated();
    notifyListeners();
  }

  /// Attempt login with the given credentials.
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _authService.login(
        AuthCredentials(email: email, password: password),
      );
      _isAuthenticated = true;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Logout and clear all auth state.
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    await _authService.logout();

    _isAuthenticated = false;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  /// Clear any current error message.
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
