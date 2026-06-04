// Authentication-related data models.

class AuthCredentials {
  final String email;
  final String password;

  const AuthCredentials({required this.email, required this.password});

  Map<String, dynamic> toJson() => {
        'email': email,
        'password': password,
      };
}

class LoginResponse {
  final String message;
  final String? accessToken;
  final String? refreshToken;
  final String? accessCsrf;
  final String? refreshCsrf;

  const LoginResponse({
    required this.message,
    this.accessToken,
    this.refreshToken,
    this.accessCsrf,
    this.refreshCsrf,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    // Support both flat {"access_token": ...} and wrapped {"data": {"access_token": ...}}
    final payload =
        (json['data'] is Map ? json['data'] as Map<String, dynamic> : null) ??
            json;
    return LoginResponse(
      message: json['message'] ?? '',
      accessToken: payload['access_token']?.toString(),
      refreshToken: payload['refresh_token']?.toString(),
      accessCsrf: payload['access_csrf']?.toString(),
      refreshCsrf: payload['refresh_csrf']?.toString(),
    );
  }
}
