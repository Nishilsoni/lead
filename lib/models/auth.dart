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
    return LoginResponse(
      message: json['message'] ?? '',
      accessToken: json['access_token'],
      refreshToken: json['refresh_token'],
      accessCsrf: json['access_csrf'],
      refreshCsrf: json['refresh_csrf'],
    );
  }
}
