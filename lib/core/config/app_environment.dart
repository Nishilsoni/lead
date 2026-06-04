enum AppEnvironment { test, prod }

extension AppEnvironmentConfig on AppEnvironment {
  String get baseUrl {
    switch (this) {
      case AppEnvironment.test:
        return 'https://test-api.crm.oceantechnolab.com/api';
      case AppEnvironment.prod:
        return 'https://api.crm.oceantechnolab.com/api';
    }
  }

  String get label {
    switch (this) {
      case AppEnvironment.test: return 'Test';
      case AppEnvironment.prod: return 'Production';
    }
  }

  // Env-prefixed storage keys — test and prod tokens never collide
  String get accessTokenKey => '${name}_access_token';
  String get refreshTokenKey => '${name}_refresh_token';
  String get orgIdKey => '${name}_org_id';
}
